(** [Canary_status] — `canary status <project>`: reconstruct the
    per-variant × per-step verdict matrix from a project's [actions.log].

    The persisted [run_state.json] / [result.html] collapse a multi-variant
    run to the first variant's steps + a merged status (dedup by tag), so
    the per-variant detail (z3 dev/stable, llvm dev/19, ssl-variant's 2×2)
    is only in [actions.log] — as [variant_start] markers + per-step
    [done]/[failed] verdicts. This command parses that back into a matrix.

    General: works for any project. Single-run projects (no [variant_start])
    show under one "(run)" group. *)

open Base

let log_path ~root ~project =
  Printf.sprintf "%s/canary/projects/%s/-run/actions.log" root project

(** Projects under [root] that have a run to report (an [actions.log]).
    Drives `status @all`. *)
let projects_with_runs ~root : string list =
  let dir = Printf.sprintf "%s/canary/projects" root in
  match Stdlib.Sys.readdir dir with
  | exception _ -> []
  | entries ->
      Array.to_list entries
      |> List.filter ~f:(fun p ->
             Stdlib.Sys.file_exists (log_path ~root ~project:p))
      |> List.sort ~compare:String.compare

(* Split a log line into (tag, event, detail) after the "[timestamp]"
   prefix. Splits on runs of 2+ spaces so a single-spaced detail like
   "(expected failure confirmed)" stays intact. *)
let parse_line (line : string) : (string * string * string option) option =
  match String.index line ']' with
  | None -> None
  | Some i ->
      let rest = String.subo line ~pos:(i + 1) |> String.lstrip in
      let parts =
        Str.split (Str.regexp "  +") rest
        |> List.filter ~f:(fun s -> not (String.is_empty s))
      in
      (match parts with
       | tag :: event :: ds ->
           let detail =
             match ds with [] -> None | _ -> Some (String.concat ~sep:" " ds)
           in
           Some (tag, event, detail)
       | _ -> None)

let strip_parens s =
  s
  |> String.chop_prefix_if_exists ~prefix:"("
  |> String.chop_suffix_if_exists ~suffix:")"

(* Terminal per-step verdict events worth surfacing. *)
let is_verdict = function
  | "done" | "failed" | "blocked" | "skip" | "unexpected_success" -> true
  | _ -> false

(* The confirming-agreement suffix the runner appends to xfail details
   (" [api_names_present]" / " [a,b]") — extracted so the mark itself
   can name the agreement ("xfail[api_names_present]"). "" when the
   detail carries none (an unattributed xfail, or an older log line).

   It used to search for the literal "[c", which was the c1..c9
   numbering baked into a parser (2026-09-12). Now it takes the
   trailing bracket group and keeps it only if every name inside is a
   REGISTERED agreement — so a log line ending in some other bracketed
   text is not mistaken for an attribution, and a line naming a retired
   id shows as an unattributed xfail rather than citing something that
   no longer exists. *)
let agreement_suffix (detail : string option) : string =
  match detail with
  | None -> ""
  | Some d -> (
      (* the LAST bracket group in the line — the detail may still be
         wrapped in the log's own parentheses, so this does not anchor
         at the end *)
      match String.rindex d ']' with
      | None -> ""
      | Some j -> (
          match String.rindex (String.sub d ~pos:0 ~len:j) '[' with
          | None -> ""
          | Some i ->
              let inner = String.sub d ~pos:(i + 1) ~len:(j - i - 1) in
              let names =
                String.split inner ~on:',' |> List.map ~f:String.strip
              in
              if
                (not (List.is_empty names))
                && List.for_all names ~f:(fun s ->
                       Option.is_some
                         (Canary_agreement_common.agreement_id_of_string s))
              then String.sub d ~pos:i ~len:(j - i + 1)
              else ""))

(* Compact mark from (event, detail). `xfail` = an *expected* failure that
   was confirmed (a pass) — the "done (expected failure confirmed)" text is
   redundant with the mark, so the row drops it; the confirming contract
   (if the runner named one) rides the mark: "xfail[c2]". *)
let mark event detail =
  match event with
  | "done" -> (
      match detail with
      | Some d when String.is_substring d ~substring:"expected failure" ->
          "xfail" ^ agreement_suffix detail
      | _ -> "✓")
  | "failed" -> "✗"
  | "unexpected_success" -> "✗"
  | "skip" -> (
      (* a cache skip on a MET expectation is a pass, not a not-run: the
         verdict marker's flavor tells which pass. *)
      match detail with
      | Some d when String.is_substring d ~substring:"prior xfail" ->
          "xfail" ^ agreement_suffix detail
      | Some d when String.is_substring d ~substring:"prior success" -> "✓"
      | _ -> "·")
  | "blocked" -> "⊘"
  | _ -> "?"

let read_file_or_empty path =
  try Stdlib.In_channel.with_open_text path Stdlib.In_channel.input_all
  with _ -> ""

(* ── install-diff (status §B build-config divergence, slice (ii)) ──
   Compare the BUILD-TREE native inspect against the STAGED one for a
   variant: with `install_lib` a real `cmake --install`, the staged
   artifact is a genuinely transformed copy — this note surfaces whether
   the transformation changed what the inspects capture (symbol counts,
   SONAME, RPATH/RUNPATH, NEEDED). "identical" is itself a finding (no
   install-time drift for this project/flags); a difference is the
   build-config divergence made visible. [None] = either side missing. *)
let install_diff_note ~root ~project ~variant : string option =
  let project_name =
    match String.lsplit2 project ~on:'/' with Some (p, _) -> p | None -> project
  in
  let inspect_of step_dir =
    let file =
      Canary_basic.filename ~variant_key:variant ~base:"inspect" ~ext:"json"
    in
    let path =
      Printf.sprintf "%s/canary/projects/%s/%s/%s" root project_name step_dir
        file
    in
    try Some (Yojson.Basic.from_file path) with _ -> None
  in
  match (inspect_of "probe_lib", inspect_of "probe_lib_staged") with
  | Some bt, Some st ->
      let open Yojson.Basic.Util in
      let total j =
        try j |> member "counts" |> member "total" |> to_int with _ -> -1
      in
      let elf_str j k =
        try
          match j |> member "elf" |> member k with
          | `String s -> s
          | `Null -> "-"
          | `List xs ->
              String.concat ~sep:","
                (List.filter_map xs ~f:(function `String s -> Some s | _ -> None))
          | _ -> "-"
        with _ -> "-"
      in
      let diffs =
        List.filter_map
          [ ("symbols", Int.to_string (total bt), Int.to_string (total st));
            ("soname", elf_str bt "soname", elf_str st "soname");
            ("runpath", elf_str bt "runpath", elf_str st "runpath");
            ("rpath", elf_str bt "rpath", elf_str st "rpath");
            ("needed", elf_str bt "needed", elf_str st "needed") ]
          ~f:(fun (k, b, s) ->
            if String.equal b s then None
            else Some (Printf.sprintf "%s %s→%s" k b s))
      in
      Some
        (match diffs with
         | [] -> "install-diff vs build-tree: identical"
         | ds -> "⚠ install-diff: " ^ String.concat ~sep:"; " ds)
  | _ -> None

(* Compact watchlist verdict for a step row, aggregated over the step's
   .json witnesses for this variant: "watchlist 5/5" when all present,
   "⚠ watchlist MISSING a,b" otherwise. [None] = no watchlist data. Gated
   to inspect-ish tags by the caller (avoid reading files for every row). *)
let watchlist_note ~root ~project ~variant ~tag : string option =
  let project_name =
    match String.lsplit2 project ~on:'/' with Some (p, _) -> p | None -> project
  in
  let vk = if String.equal variant "(run)" then "" else variant in
  (* an inspect step writes its JSON into the PARENT action's output dir
     (build_lib_inspect → build_lib/, probe_binding_ocaml_inspect →
     probe_binding/ocaml/) — strip the suffix before the dir mapping. *)
  let parent_tag =
    match String.chop_suffix tag ~suffix:"_inspect" with
    | Some t -> t
    | None -> tag
  in
  let dir =
    Printf.sprintf "%s/canary/projects/%s/%s" root project_name
      (Canary_basic.step_dir_of_tag parent_tag)
  in
  match Stdlib.Sys.readdir dir with
  | exception _ -> None
  | files ->
      (* Two watchlist ROLES per inspect JSON (status.md §B, 2026-08-05):
         - watchlist.{present,missing} — EXPECTED-PRESENT: missing = drift,
           alarming ("⚠ MISSING");
         - expected_missing.{confirmed,violated} — EXPECTED-MISSING (e.g.
           sqlite's binding-lag markers): confirmed = the declared absence
           holds (an xfail-style pass, "lag confirmed"); violated = the
           name APPEARED (binding caught up; declaration stale — "✗ lag
           REAPPEARED"). Older JSONs lack the section — read as empty. *)
      let present, missing, confirmed, violated =
        Array.fold files ~init:(0, [], [], [])
          ~f:(fun (np, miss, conf, viol) f ->
            if
              String.is_suffix f ~suffix:".json"
              && String.is_substring f ~substring:vk
            then
              try
                let j = Yojson.Basic.from_file (Printf.sprintf "%s/%s" dir f) in
                let open Yojson.Basic.Util in
                let strs sect k =
                  try
                    j |> member sect |> member k |> to_list
                    |> List.map ~f:to_string
                  with _ -> []
                in
                ( np + List.length (strs "watchlist" "present"),
                  miss @ strs "watchlist" "missing",
                  conf @ strs "expected_missing" "confirmed",
                  viol @ strs "expected_missing" "violated" )
              with _ -> (np, miss, conf, viol)
            else (np, miss, conf, viol))
      in
      if
        present = 0 && List.is_empty missing && List.is_empty confirmed
        && List.is_empty violated
      then None
      else
        let base =
          if List.is_empty missing then
            Printf.sprintf "watchlist %d/%d" present present
          else
            Printf.sprintf "⚠ watchlist MISSING %s"
              (String.concat ~sep:"," missing)
        in
        let parts =
          [ Some base;
            (if List.is_empty violated then None
             else
               Some
                 (Printf.sprintf "✗ lag REAPPEARED %s (declaration stale)"
                    (String.concat ~sep:"," violated)));
            (if List.is_empty confirmed then None
             else
               Some
                 (Printf.sprintf "xfail lag %s"
                    (String.concat ~sep:"," confirmed))) ]
        in
        Some (String.concat ~sep:" · " (List.filter_opt parts))

(* THE EVIDENCE A STEP LEFT IN THE LOG (2026-08-20, plan item A1/A3).

   [project_matrix] keeps one verdict per tag — it is a matrix. Evidence
   is the opposite shape: several lines per step, order-significant. So
   this re-scans actions.log and returns, for one (variant, tag), the
   [note] lines a step chose to keep and the [cmd_out] tail of a failure.

   The point of reading it from the LOG rather than from files on disk:
   the log is what gets attached to an issue, and what a rerun compares
   against. If the reason is not in there, it is not reportable. *)
let evidence_of ~root ~project ~variant ~tag =
  let path = log_path ~root ~project in
  if not (Stdlib.Sys.file_exists path) then []
  else
    let lines =
      Stdlib.In_channel.with_open_text path Stdlib.In_channel.input_lines
    in
    let cur = ref "(run)" in
    let acc = ref [] in
    List.iter lines ~f:(fun line ->
        match parse_line line with
        | Some (_, "variant_start", detail) ->
            cur := Option.value_map detail ~default:"(run)" ~f:strip_parens;
            (* actions.log is APPEND-ONLY across runs, so a variant appears
               once per run and its evidence accumulates. Only the LAST
               visit describes the current state — re-entering the variant
               discards what earlier runs said, the same "last verdict
               wins" rule [project_matrix] uses for marks. Without this a
               step shows evidence from a run whose bug is already fixed. *)
            if String.equal !cur variant then acc := []
        | Some (t, (("note" | "cmd_out") as event), Some detail)
          when String.equal t tag && String.equal !cur variant ->
            acc := (event, strip_parens detail) :: !acc
        | _ -> ());
    List.rev !acc

(* Verbose witness for a step: the output file(s) it produced for this
   variant (openable), and — for `xfail`/`✗` — the tail of a `.log` witness
   as the concrete failure. *)
let print_witness ~root ~project ~variant ~tag ~mark =
  let project_name =
    match String.lsplit2 project ~on:'/' with Some (p, _) -> p | None -> project
  in
  let vk = if String.equal variant "(run)" then "" else variant in
  let dir =
    Printf.sprintf "%s/canary/projects/%s/%s" root project_name
      (Canary_basic.step_dir_of_tag tag)
  in
  let matches =
    match Stdlib.Sys.readdir dir with
    | exception _ -> []
    | files ->
        Array.to_list files
        |> List.filter ~f:(fun f -> String.is_substring f ~substring:vk)
        |> List.sort ~compare:String.compare
  in
  (* the log's own evidence comes FIRST — it is the reason, where the file
     list is only where to look next (A1/A3, 2026-08-20). Notes show on
     any verdict ("provided ⊇ required" is evidence too); the captured
     failure tail shows only when the step is red. *)
  let evidence = evidence_of ~root ~project ~variant ~tag in
  let is_red = String.is_prefix mark ~prefix:"xfail" || String.equal mark "✗" in
  List.iter evidence ~f:(fun (event, detail) ->
      match event with
      | "note" -> Stdlib.Printf.printf "          ● %s\n" detail
      | "cmd_out" when is_red -> Stdlib.Printf.printf "          │ %s\n" detail
      | _ -> ());
  List.iter matches ~f:(fun f ->
      Stdlib.Printf.printf "          → %s/%s\n" dir f;
      (* inspect JSONs: summarize the native-watchlist verdict inline (the
         content, not just the path — e.g. build_lib_inspect's per-version
         symbol watchlist). *)
      if String.is_suffix f ~suffix:".json" then
        try
          let j = Yojson.Basic.from_file (Printf.sprintf "%s/%s" dir f) in
          let open Yojson.Basic.Util in
          let strs k =
            j |> member "watchlist" |> member k |> to_list |> List.map ~f:to_string
          in
          match (strs "present", strs "missing") with
          | [], [] -> ()
          | present, [] ->
              Stdlib.Printf.printf "            | watchlist: %d/%d present\n"
                (List.length present) (List.length present)
          | present, missing ->
              Stdlib.Printf.printf
                "            | watchlist: %d present, MISSING %s\n"
                (List.length present)
                (String.concat ~sep:"," missing)
        with _ -> ());
  if String.is_prefix mark ~prefix:"xfail" || String.equal mark "✗" then
    List.iter matches ~f:(fun f ->
        if String.is_suffix f ~suffix:".log" then begin
          let content = read_file_or_empty (Printf.sprintf "%s/%s" dir f) in
          let lines =
            String.split_lines content
            |> List.filter ~f:(fun l -> not (String.is_empty (String.strip l)))
          in
          let tail = List.drop lines (Int.max 0 (List.length lines - 4)) in
          List.iter tail ~f:(fun l -> Stdlib.Printf.printf "            | %s\n" l)
        end)

(** The per-scenario × per-tag verdict matrix read from the shared
    actions.log — the ONLY per-scenario run record (run_state.json
    merges scenarios last-writer-wins; verdict markers exist only on
    MET expectations). [(scenario, (tag, (event, detail)) list)] in
    first-seen scenario order, first-seen tag order, last verdict
    winning. Shared by the [status] view and the cross-project result
    matrix ([Canary_matrix]). *)
let project_matrix ~root ~project :
    (string * (string * (string * string option)) list) list =
  let path = log_path ~root ~project in
  if not (Stdlib.Sys.file_exists path) then []
  else begin
    let lines =
      Stdlib.In_channel.with_open_text path Stdlib.In_channel.input_lines
    in
    (* Ordered variants (first-seen); each a tag→(event,detail) assoc kept
       in first-seen order with last verdict winning. *)
    let order = ref [] in
    let table : (string, (string * (string * string option)) list ref) Hashtbl.t =
      Hashtbl.create (module String)
    in
    let cur = ref "(run)" in
    let ensure name =
      match Hashtbl.find table name with
      | Some r -> r
      | None ->
          let r = ref [] in
          Hashtbl.set table ~key:name ~data:r;
          order := name :: !order;
          r
    in
    List.iter lines ~f:(fun line ->
        match parse_line line with
        | Some (_, "variant_start", detail) ->
            cur := Option.value_map detail ~default:"(run)" ~f:strip_parens
        | Some (tag, event, detail) when is_verdict event ->
            let r = ensure !cur in
            (* drop any prior verdict for this tag, then append (last wins,
               preserves first-seen column order) *)
            r :=
              List.filter !r ~f:(fun (t, _) -> not (String.equal t tag))
              @ [ (tag, (event, detail)) ]
        | _ -> ());
    List.map (List.rev !order) ~f:(fun name ->
        ( name,
          match Hashtbl.find table name with Some r -> !r | None -> [] ))
  end

let print_status ?(verbose = false) ~root ~project () =
  let path = log_path ~root ~project in
  if not (Stdlib.Sys.file_exists path) then
    Stdlib.Printf.printf
      "No run found for %s (expected %s).\nRun `canary action %s` first.\n"
      project path project
  else begin
    let variants = project_matrix ~root ~project in
    (* "scenario" is THE display term (ssot §6.1: scenario ≡ variant; the
       enumerated "world" was the same thing) — code ids like [variant_id]
       remain the scenario's cache/filename key. *)
    Stdlib.Printf.printf "\n%s — %d scenario(s)\n" project (List.length variants);
    List.iter variants ~f:(fun (name, verdicts) ->
        (* one-line summary mark for the variant = worst of its steps *)
        let overall =
          if List.exists verdicts ~f:(fun (_, (e, _)) ->
                 String.equal e "failed" || String.equal e "unexpected_success")
          then "✗"
          else "✓"
        in
        Stdlib.Printf.printf "\n  %s  %s\n" overall name;
        List.iter verdicts ~f:(fun (tag, (event, detail)) ->
            let m = mark event detail in
            (* detail adds info beyond the mark only on a real failure *)
            let extra =
              match event with
              | "failed" | "unexpected_success" ->
                  Option.value_map detail ~default:"" ~f:(fun d -> "  " ^ d)
              | _ -> ""
            in
            let wnote =
              if String.is_substring tag ~substring:"inspect"
                 || String.is_substring tag ~substring:"scan"
              then
                match watchlist_note ~root ~project ~variant:name ~tag with
                | Some s -> "  " ^ s
                | None -> ""
              else ""
            in
            (* build-tree vs staged comparison rides the STAGED inspect row *)
            let inote =
              if String.equal tag "probe_lib_staged_inspect" then
                match install_diff_note ~root ~project ~variant:name with
                | Some s -> "  " ^ s
                | None -> ""
              else ""
            in
            Stdlib.Printf.printf "      %-28s %-10s%s%s%s\n" tag m extra wnote
              inote;
            if verbose then
              print_witness ~root ~project ~variant:name ~tag ~mark:m))
  end

(* ── OBSERVED AGREEMENTS (2026-09-12) ──────────────────────────────

   The round-trip. Everything else in the agreement layer describes
   what WOULD be checked: the registry lists the methods, the firing
   table says where they apply, the checking index reports what a
   project's actions would select. None of that is evidence that a
   check ran, and the first real project this was pointed at turned out
   to evaluate ten agreements into `unavailable` at every step, because
   the inspectors it declared were wired into a spec the run path never
   used.

   So this reads the other direction: parse a run's own [actions.log]
   and report, per agreement, the outcomes it actually reached. A
   catalogue row is CONCRETE when a real project's log shows it
   `holds` or `violated`; anything else is a declaration. *)

type observed = {
  ob_agreement : string;
  ob_method : string;
  ob_outcomes : (string * int) list;  (** outcome label → how many times *)
}

(** What the last run did, as a whole: the agreements it evaluated, and
    how many steps it SKIPPED. The second number is not a footnote — a
    warm step reports nothing, so a run that skipped everything shows
    an empty agreement table and means "nothing was re-checked", not
    "nothing applies". Reading one without the other is how a stale
    report passes for a current one. *)
type run_observation = {
  ro_agreements : observed list;
  ro_skipped_steps : int;
  ro_ran_steps : int;
}

(** Parse the [agreement_outcome] detail the runner writes, which is
    ["<agreement>/<method>: <label>[: reason]"]. Returns [None] for the
    "no agreement fires at this action" line, which names no agreement. *)
let parse_agreement_outcome (detail : string) : (string * string * string) option
    =
  let d = strip_parens (String.strip detail) in
  match String.lsplit2 d ~on:':' with
  | None -> None
  | Some (head, rest) -> (
      match String.lsplit2 head ~on:'/' with
      | None -> None
      | Some (agreement, meth) ->
          let label =
            String.strip rest |> fun r ->
            match String.lsplit2 r ~on:':' with
            | Some (l, _) -> String.strip l
            | None -> r
          in
          if String.is_empty agreement || String.is_empty meth then None
          else Some (String.strip agreement, String.strip meth, label))

(** The lines belonging to the LAST run — everything after the final
    [run_start] marker. [actions.log] is append-only across
    invocations, so without this a reader reports the union of every
    run the file has ever held, and a step that was warm-skipped today
    still shows the outcome it produced a week ago. A log with no
    marker at all predates the marker and is read whole, which is the
    only honest thing to do with it. *)
let is_run_start l =
  match parse_line l with Some (_, "run_start", _) -> true | _ -> false

(** The log split into RUNS, newest first. [actions.log] is append-only
    across invocations; a [run_start] marker delimits them. A log with
    no marker predates the marker and is one block, which is the only
    honest thing to do with it. *)
let run_blocks ~root ~project : string list list =
  let path = log_path ~root ~project in
  let all =
    try
      Stdlib.In_channel.with_open_text path (fun ic ->
          let rec loop acc =
            match Stdlib.In_channel.input_line ic with
            | None -> List.rev acc
            | Some l -> loop (l :: acc)
          in
          loop [])
    with _ -> []
  in
  if List.is_empty all then []
  else if not (List.exists all ~f:is_run_start) then [ all ]
  else
    let blocks, last =
      List.fold all ~init:([], []) ~f:(fun (blocks, cur) l ->
          if is_run_start l then
            ((if List.is_empty cur then blocks else List.rev cur :: blocks), [])
          else (blocks, l :: cur))
    in
    let blocks = if List.is_empty last then blocks else List.rev last :: blocks in
    (* [blocks] accumulated newest-first already *)
    blocks

let last_run_lines ~root ~project : string list =
  match run_blocks ~root ~project with b :: _ -> b | [] -> []

(** What one run's lines say. Ordered by agreement name so two runs
    diff cleanly. *)
let observe_lines (lines : string list) : run_observation =
  let tbl : (string * string, (string, int) Hashtbl.t) Hashtbl.t =
    Hashtbl.Poly.create ()
  in
  let skipped = ref 0 and ran = ref 0 in
  List.iter lines ~f:(fun line ->
      match parse_line line with
      | Some (_, "agreement_outcome", Some detail) -> (
          match parse_agreement_outcome detail with
          | None -> ()
          | Some (ag, meth, label) ->
              let counts =
                Hashtbl.find_or_add tbl (ag, meth) ~default:(fun () ->
                    Hashtbl.create (module String))
              in
              Hashtbl.update counts label ~f:(function
                | None -> 1
                | Some n -> n + 1))
      | Some (_, "skip", _) -> Int.incr skipped
      | Some (tag, "done", _) when not (String.equal tag "*") -> Int.incr ran
      | _ -> ());
  let agreements =
    Hashtbl.to_alist tbl
  |> List.map ~f:(fun ((ag, meth), counts) ->
         { ob_agreement = ag;
           ob_method = meth;
           ob_outcomes =
             Hashtbl.to_alist counts
             |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b) })
    |> List.sort ~compare:(fun a b ->
           match String.compare a.ob_agreement b.ob_agreement with
           | 0 -> String.compare a.ob_method b.ob_method
           | c -> c)
  in
  { ro_agreements = agreements; ro_skipped_steps = !skipped; ro_ran_steps = !ran }

let observe_run ~root ~project : run_observation =
  observe_lines (last_run_lines ~root ~project)

let observed_agreements ~root ~project : observed list =
  (observe_run ~root ~project).ro_agreements

(** ONE AGREEMENT OUTCOME, WITH THE TWO COORDINATES THE OTHER READERS
    DROP (2026-09-14).

    [observe_lines] answers "what did this run check, and to what" and
    aggregates over the whole run — it discards both the step tag and
    the scenario, which is right for a landing tracker and useless for
    a table whose rows ARE scenarios. [project_matrix] keeps the
    scenario and the tag but ignores [agreement_outcome] entirely.
    Neither produces (scenario, tag, agreement, outcome), which is
    what a per-cell view needs. *)
type agreement_obs = {
  ao_tag : string;  (** the step that evaluated it *)
  ao_agreement : string;
  ao_method : string;
  ao_outcome : string;  (** holds | violated | unavailable | … *)
}

(** Every agreement outcome in the log, per scenario.

    It reads the WHOLE file, last-wins, exactly as {!project_matrix}
    does — the result table is a view of "the last thing known about
    each cell", not of one invocation. The consequence is worth stating
    because it differs from a verdict's: a warm-skipped step logs no
    agreement line at all, so a warm scenario keeps showing the
    outcomes of whenever it last ran cold, with nothing in the cell to
    say so. A verdict at least logs [skip (prior success)]. Accepted
    deliberately (2026-09-14, user): the landed agreements are verified
    on projects that run cold in [canary-post-check], and a stale cell
    elsewhere is a display question rather than a soundness one. *)
let project_agreements ~root ~project :
    (string * agreement_obs list) list =
  let path = log_path ~root ~project in
  if not (Stdlib.Sys.file_exists path) then []
  else begin
    let lines =
      Stdlib.In_channel.with_open_text path Stdlib.In_channel.input_lines
    in
    let order = ref [] in
    let table : (string, agreement_obs list ref) Hashtbl.t =
      Hashtbl.create (module String)
    in
    let cur = ref "(run)" in
    let ensure name =
      match Hashtbl.find table name with
      | Some r -> r
      | None ->
          let r = ref [] in
          Hashtbl.set table ~key:name ~data:r;
          order := name :: !order;
          r
    in
    List.iter lines ~f:(fun line ->
        match parse_line line with
        | Some (_, "variant_start", detail) ->
            cur := Option.value_map detail ~default:"(run)" ~f:strip_parens
        | Some (tag, "agreement_outcome", Some detail) -> (
            match parse_agreement_outcome detail with
            | None -> ()  (* the "no agreement fires here" line *)
            | Some (ag, meth, label) ->
                let r = ensure !cur in
                let o =
                  { ao_tag = tag; ao_agreement = ag; ao_method = meth;
                    ao_outcome = label }
                in
                (* last wins per (tag, agreement, method), first-seen
                   order preserved — the same rule the verdict table
                   uses, so a re-run replaces rather than appends *)
                r :=
                  List.filter !r ~f:(fun p ->
                      not
                        (String.equal p.ao_tag tag
                        && String.equal p.ao_agreement ag
                        && String.equal p.ao_method meth))
                  @ [ o ])
        | _ -> ());
    List.map (List.rev !order) ~f:(fun name ->
        ( name,
          match Hashtbl.find table name with Some r -> !r | None -> [] ))
  end

(** THE MOST RECENT RUN THAT ACTUALLY EVALUATED each agreement, and how
    many runs ago that was (0 = the latest run).

    Scanning only the latest run was wrong, and the way it was wrong is
    worth keeping in mind: a warm run evaluates nothing, so re-running
    anything made a landed agreement look unlanded. "Has a real run
    decided this" is not a property of the newest run, it is a property
    of the newest run THAT LOOKED. Reporting the age alongside keeps it
    from drifting into "was true once": a regression still shows,
    because the run that regressed is the newest one that looked. *)
let latest_observation ~root ~project (slug : string) :
    (observed list * int) option =
  List.find_mapi (run_blocks ~root ~project) ~f:(fun age lines ->
      match
        List.filter (observe_lines lines).ro_agreements ~f:(fun o ->
            String.equal o.ob_agreement slug)
      with
      | [] -> None
      | os -> Some (os, age))

(** Did this run DECIDE the agreement anywhere — reach [holds] or
    [violated] rather than only reporting why it could not? The
    predicate a round-trip assertion uses. *)
let decided_in_run (o : observed) : bool =
  List.exists o.ob_outcomes ~f:(fun (label, _) ->
      String.equal label "holds" || String.equal label "violated")

let pp_observed ~root ~project : string =
  let r = observe_run ~root ~project in
  let obs = r.ro_agreements in
  let warm =
    if r.ro_skipped_steps > 0 then
      Printf.sprintf
        "\n  NOTE: %d step(s) were warm-skipped and re-checked nothing; %d ran."
        r.ro_skipped_steps r.ro_ran_steps
    else ""
  in
  if List.is_empty obs then
    Printf.sprintf
      "%s — the last run evaluated no agreement.%s" project warm
  else
    let line (o : observed) =
      Printf.sprintf "  %-28s %-40s %s%s" o.ob_agreement o.ob_method
        (String.concat ~sep:", "
           (List.map o.ob_outcomes ~f:(fun (l, n) ->
                Printf.sprintf "%s x%d" l n)))
        (if decided_in_run o then "   ← decided" else "")
    in
    let decided = List.count obs ~f:decided_in_run in
    String.concat ~sep:"\n"
      ((Printf.sprintf "%s — agreements OBSERVED in the last run" project)
       :: List.map obs ~f:line
      @ [ Printf.sprintf
            "\n  %d of %d evaluated methods reached a decided outcome \
             (holds/violated) in this run.%s"
            decided (List.length obs) warm ])

(* ── THE LANDING TRACKER (2026-09-12) ──────────────────────────────

   Two columns, and the whole point is that they are different
   questions answered from different places:

   - PLANNED comes from the REGISTRY. Does this agreement have a
     method with an evaluator, and does that evaluator ship a
     counterexample? It is a fact about the code and is true in a fresh
     checkout with no runs at all.
   - EFFECTIVE comes from RUN LOGS. Has a real project ever decided
     this agreement — reached `holds` or `violated` rather than only
     reporting why it could not? It is a fact about what happened.

   An agreement can be fully planned and never effective, and that gap
   is the thing worth tracking: it is what "the comparator exists" felt
   like before anyone read a log. Nothing derives one column from the
   other, which is why both are worth printing side by side. *)

type effective =
  | Decided of string list       (** projects whose last run decided it *)
  | Reported of string list      (** selected, never decided — with the reason *)
  | Never_selected

let string_of_effective = function
  | Decided ps -> "decided in " ^ String.concat ~sep:"," ps
  | Reported ps -> "reported only (" ^ String.concat ~sep:"," ps ^ ")"
  | Never_selected -> "never selected"

type landing_row = {
  la_agreement : string;
  la_planned : string;        (** the registry's own status word *)
  la_has_counterexample : bool;
  la_effective : effective;
  la_undecided_reasons : string list;  (** the outcome labels seen instead *)
}

let is_landed (r : landing_row) : bool =
  match r.la_effective with Decided _ -> true | _ -> false

(** The tracker. [projects] defaults to every project under [root] with
    a run to read. *)
let landing ?projects ~root () : landing_row list =
  let projects =
    match projects with Some p -> p | None -> projects_with_runs ~root
  in
  List.map Canary_agreement.agreement_registry ~f:(fun r ->
      let slug = r.Canary_agreement.ag_slug in
      (* per project, the most recent run that LOOKED at this agreement *)
      let hits =
        List.filter_map projects ~f:(fun p ->
            match latest_observation ~root ~project:p slug with
            | None -> None
            | Some (os, age) -> Some (p, os, age))
      in
      let label p age = if age = 0 then p else Printf.sprintf "%s(-%d)" p age in
      let decided_in =
        List.filter_map hits ~f:(fun (p, os, age) ->
            if List.exists os ~f:decided_in_run then Some (label p age) else None)
      in
      let reasons =
        List.concat_map hits ~f:(fun (_, os, _) ->
            List.concat_map os ~f:(fun o -> List.map o.ob_outcomes ~f:fst))
        |> List.dedup_and_sort ~compare:String.compare
      in
      { la_agreement = slug;
        la_planned =
          Canary_agreement.string_of_status (Canary_agreement.status_of_row r);
        la_has_counterexample =
          Canary_agreement.has_fixture r.Canary_agreement.ag_id;
        la_effective =
          (if not (List.is_empty decided_in) then Decided decided_in
           else if List.is_empty hits then Never_selected
           else Reported (List.map hits ~f:(fun (p, _, age) -> label p age)));
        la_undecided_reasons = reasons })

let pp_landing ?projects ~root () : string =
  let rows = landing ?projects ~root () in
  let projects =
    match projects with Some p -> p | None -> projects_with_runs ~root
  in
  let landed = List.count rows ~f:is_landed in
  let line (r : landing_row) =
    Printf.sprintf "%s %-28s %-17s %-3s %s"
      (if is_landed r then "LANDED " else "       ")
      r.la_agreement r.la_planned
      (if r.la_has_counterexample then "fx" else "- ")
      (match r.la_effective with
       | Decided ps -> "decided in " ^ String.concat ~sep:", " ps
       | Reported ps ->
           Printf.sprintf "reported in %s as %s"
             (String.concat ~sep:", " ps)
             (String.concat ~sep:"/" r.la_undecided_reasons)
       | Never_selected ->
           (* NOT the same as "does not apply": a warm-skipped step
              re-checks nothing, so an agreement can be absent from a
              log simply because the step that selects it was cached *)
           "absent from every log read (never fired, or its step was \
            warm-skipped)")
  in
  String.concat ~sep:"\n"
    ([ "agreement landing — PLANNED (from the registry) vs EFFECTIVE (from run logs)";
       Printf.sprintf "  reading runs of: %s"
         (if List.is_empty projects then "(none)"
          else String.concat ~sep:", " projects);
       "  effective = the most recent run that LOOKED at the agreement, not";
       "  the most recent run — a warm run evaluates nothing. `p(-n)` means";
       "  n runs back in p's log.";
       "";
       Printf.sprintf "%s %-28s %-17s %-3s %s" "       " "agreement" "planned"
         "fx" "effective" ]
    @ List.map rows ~f:line
    @ [ "";
        Printf.sprintf
          "  %d of %d agreements are LANDED — decided by a real run. \
           `fx` = ships a counterexample."
          landed (List.length rows);
        "  Planned is a fact about the code; effective is a fact about what ran.";
        "  Neither is derived from the other." ])

(** The EFFECTIVE half of one agreement's record: what real runs did
    with it. The registry can describe an agreement completely and
    still not know whether anything ever looked; this is the part only
    a log can answer, kept separate for exactly that reason. *)
let pp_agreement_effective ~root ~name : string =
  let rows = landing ~root () in
  match List.find rows ~f:(fun r -> String.equal r.la_agreement name) with
  | None -> ""
  | Some r ->
      let per_project =
        List.filter_map (projects_with_runs ~root) ~f:(fun p ->
            match latest_observation ~root ~project:p name with
            | None -> None
            | Some (os, age) ->
                Some
                  (Printf.sprintf "    %-14s %s%s" p
                     (String.concat ~sep:", "
                        (List.concat_map os ~f:(fun o ->
                             List.map o.ob_outcomes ~f:(fun (l, n) ->
                                 Printf.sprintf "%s x%d" l n))))
                     (if age = 0 then "" else Printf.sprintf "  (%d run(s) ago)" age)))
      in
      String.concat ~sep:"\n"
        ([ "  EFFECTIVE — what real runs did (the registry cannot know this)";
           Printf.sprintf "    %-12s %s"
             (if is_landed r then "LANDED" else "not landed")
             (string_of_effective r.la_effective) ]
        @ (if List.is_empty per_project then
             [ "    no run has selected it" ]
           else per_project))

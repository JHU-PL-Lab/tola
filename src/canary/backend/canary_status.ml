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

(* Compact mark from (event, detail). `xfail` = an *expected* failure that
   was confirmed (a pass) — the "done (expected failure confirmed)" text is
   redundant with the mark, so the row drops it. *)
let mark event detail =
  match event with
  | "done" -> (
      match detail with
      | Some d when String.is_substring d ~substring:"expected failure" -> "xfail"
      | _ -> "✓")
  | "failed" -> "✗"
  | "unexpected_success" -> "✗"
  | "skip" -> (
      (* a cache skip on a MET expectation is a pass, not a not-run: the
         verdict marker's flavor tells which pass. *)
      match detail with
      | Some d when String.is_substring d ~substring:"prior xfail" -> "xfail"
      | Some d when String.is_substring d ~substring:"prior success" -> "✓"
      | _ -> "·")
  | "blocked" -> "⊘"
  | _ -> "?"

let read_file_or_empty path =
  try Stdlib.In_channel.with_open_text path Stdlib.In_channel.input_all
  with _ -> ""

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
  if String.equal mark "xfail" || String.equal mark "✗" then
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

let print_status ?(verbose = false) ~root ~project () =
  let path = log_path ~root ~project in
  if not (Stdlib.Sys.file_exists path) then
    Stdlib.Printf.printf
      "No run found for %s (expected %s).\nRun `canary action %s` first.\n"
      project path project
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
    let variants = List.rev !order in
    (* "scenario" is THE display term (ssot §6.1: scenario ≡ variant; the
       enumerated "world" was the same thing) — code ids like [variant_id]
       remain the scenario's cache/filename key. *)
    Stdlib.Printf.printf "\n%s — %d scenario(s)\n" project (List.length variants);
    List.iter variants ~f:(fun name ->
        let verdicts = match Hashtbl.find table name with Some r -> !r | None -> [] in
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
            Stdlib.Printf.printf "      %-28s %-6s%s\n" tag m extra;
            if verbose then
              print_witness ~root ~project ~variant:name ~tag ~mark:m))
  end

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

(* Compact pass/fail mark from (event, detail). An expected failure is a
   PASS ("done" whose detail mentions "expected failure"). *)
let mark event detail =
  match event with
  | "done" -> (
      match detail with
      | Some d when String.is_substring d ~substring:"expected failure" -> "✓xfail"
      | _ -> "✓")
  | "failed" -> "✗"
  | "unexpected_success" -> "✗"
  | "skip" -> "·"
  | "blocked" -> "⊘"
  | _ -> "?"

let print_status ~root ~project =
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
    Stdlib.Printf.printf "\n%s — %d variant(s)\n" project (List.length variants);
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
            Stdlib.Printf.printf "      %-28s %-6s %s%s\n" tag (mark event detail)
              event
              (Option.value_map detail ~default:"" ~f:(fun d -> "  " ^ d))))
  end

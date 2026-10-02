(** Fixtures the test modules share. *)

open Base

(* The fixture the record pins write: a run log in the runner's own line
   shape ([Canary_step_model.create_logger]), stamped from a counter so
   every line's time is distinct and known; one script per step state the
   log can express; and a state read back out of the JSON by field name,
   independently of the encoder. Shared, so the pins agree on what a state
   is. *)
module Record_fixture = struct
  module S = Canary_status

  let rec mkdir_p dir =
    let parent = Stdlib.Filename.dirname dir in
    if String.equal dir parent || Stdlib.Sys.file_exists dir then ()
    else begin
      mkdir_p parent;
      (try Stdlib.Sys.mkdir dir 0o755 with _ -> ())
    end

  let write path text =
    mkdir_p (Stdlib.Filename.dirname path);
    let oc = Stdlib.open_out path in
    Stdlib.output_string oc text;
    Stdlib.close_out oc

  (* the platform this machine is not: a record that answered with the
     renderer's platform fails on either machine *)
  let elsewhere () =
    if String.equal (Canary_matrix.platform_label ()) "wsl_ubuntu" then
      "macos_local"
    else "wsl_ubuntu"

  (* one script per state the log can express: the lines the runner
     writes for it, and the state they must read as. Every script's last
     line is its verdict. *)
  let scripts ~platform : ((string * string option) list * S.step_state) list
      =
    let xfail_confirmed =
      "expected failure confirmed (derived) [api_names_present]"
    in
    [ ([ ("platform", Some platform); ("done", None) ], S.Ran S.Pass);
      ( [ ("warm_gate", Some "marker + fingerprint + check_post passed");
          ("skip", Some "verdict marker (prior success)") ],
        S.Warm S.Pass );
      ( [ ("platform", Some platform); ("done", Some xfail_confirmed) ],
        S.Ran (S.Xfail [ "api_names_present" ]) );
      ( [ ("platform", Some platform); ("failed", Some "postcondition failed") ],
        S.Ran S.Fail );
      ( [ ("skip", Some "verdict marker (prior xfail) [api_names_present]") ],
        S.Warm (S.Xfail [ "api_names_present" ]) );
      ( [ ("check_pre", Some "FAIL"); ("blocked", Some "precondition failed") ],
        S.Blocked );
      ([], S.Unrecorded);
      (* a re-run: the last verdict wins, and so does its time *)
      ( [ ("platform", Some platform);
          ("failed", Some "postcondition failed");
          ("platform", Some platform); ("done", None) ],
        S.Ran S.Pass ) ]

  type log = { buf : Buffer.t; mutable n : int }

  let create () = { buf = Buffer.create 4096; n = 0 }

  (* one line; returns its stamp *)
  let line (log : log) tag event detail =
    log.n <- log.n + 1;
    let stamp =
      Printf.sprintf "2026-01-01 00:%02d:%02d.000" (log.n / 60)
        (Int.rem log.n 60)
    in
    let padded =
      if String.length tag < 25 then
        tag ^ String.make (25 - String.length tag) ' '
      else tag
    in
    Buffer.add_string log.buf
      (Printf.sprintf "[%s] %s  %s%s\n" stamp padded event
         (match detail with Some d -> "  (" ^ d ^ ")" | None -> ""));
    stamp

  (* one script for [tag]: the stamp of its verdict line, which is the
     time the record must report; [None] when it writes nothing *)
  let play (log : log) ~tag ((lines, _) : (string * string option) list * _) =
    List.fold lines ~init:None ~f:(fun _ (event, detail) ->
        Some (line log tag event detail))

  let save (log : log) ~root ~project =
    write
      (Printf.sprintf "%s/canary/projects/%s/-run/actions.log" root project)
      (Buffer.contents log.buf)

  let uniq xs =
    List.fold xs ~init:[] ~f:(fun acc x ->
        if List.mem acc x ~equal:String.equal then acc else acc @ [ x ])

  let field j k =
    match j with
    | `Assoc kv -> List.Assoc.find kv k ~equal:String.equal
    | _ -> None

  let str j k = match field j k with Some (`String s) -> Some s | _ -> None

  let strs j k =
    match field j k with
    | Some (`List xs) ->
        Some (List.filter_map xs ~f:(function `String s -> Some s | _ -> None))
    | _ -> None

  let items j k = match field j k with Some (`List xs) -> xs | _ -> []

  (* a step state, read back by its field names *)
  let step_state_of_json jc : S.step_state option =
    let verdict =
      match str jc "verdict" with
      | Some "pass" -> Some S.Pass
      | Some "fail" -> Some S.Fail
      | Some "xfail" ->
          Some (S.Xfail (Option.value (strs jc "agreements") ~default:[]))
      | _ -> None
    in
    match (str jc "state", verdict) with
    | Some "ran", Some v -> Some (S.Ran v)
    | Some "warm", Some v -> Some (S.Warm v)
    | Some "blocked", None -> Some S.Blocked
    | Some "unrecorded", None -> Some S.Unrecorded
    | _ -> None
end

(* The chain-cell fixture: a log in zarith's shape, read by the pins that
   hold §2's counts and §1's badges to §1.2's cells. Both of zarith's
   worlds fetch the library, so neither has the build_lib slot the
   library's declaration checks are read at; the log decides them at
   probe_lib, where only a chain's cells see them. Beside them, one
   binding check is decided and one is not. *)
let chain_cell_fixture () :
    (Canary_project_run.project_run * Canary_matrix.t * Canary_overview_runs.view list) option =
  let project = "zarith" in
  Option.map (List.Assoc.find Canary_registry.all_projects project ~equal:String.equal)
    ~f:(fun pr ->
      let root = "_out/canary/test/counts-fixture" in
      let module F = Record_fixture in
      let log = F.create () in
      List.iter (Canary_project_run.scenarios_of pr) ~f:(fun a ->
          let scenario =
            Stdlib.Filename.basename (Canary_project_run.scenario_dir_of ~pr_name:project a)
          in
          ignore (F.line log "*" "variant_start" (Some scenario) : string);
          List.iter
            [ ("probe_lib", "declared_symbols_exported/declared_exports_vs_library: holds");
              ("probe_lib", "soname_matches_declaration/declared_soname_vs_library: undeclared");
              ("probe_binding_ocaml", "api_names_present/watchlist_vs_user_surface: holds");
              ( "probe_binding_ocaml",
                "dependencies_provided/recorded_dependencies_vs_world_providers: unavailable" ) ]
            ~f:(fun (tag, detail) ->
              ignore (F.line log tag "agreement_outcome" (Some detail) : string)));
      F.save log ~root ~project;
      let m = Canary_matrix.matrix_of ~root [ (project, pr) ] in
      (pr, m, Canary_overview_runs.views ~root m))

(* The worlds each catalogued project enumerates, muted ones included;
   every catalogued project needs a row. torch's two are the binding's
   two packagings at one upstream version, the stock package (a declared
   build xfail) and the canary-local patched one: not a channel pair. *)
let world_counts : (string * int) list =
  [ ("sqlite", 10); ("z3", 16); ("llvm", 3); ("tiny-full", 1); ("zarith", 2); ("cairo", 2);
    ("libffi", 2); ("zlib", 2); ("zstd", 2); ("ssl", 2); ("torch", 2) ]

(* The files the project-test suite's pins are written in: canary_lib's
   own, and one per subject here. *)
let test_sources () : string list =
  let dir = "src/canary/main" in
  "src/canary/test/canary_project_test.ml"
  :: (Stdlib.Sys.readdir dir |> Array.to_list
     |> List.filter ~f:(fun f ->
            String.is_prefix f ~prefix:"canary_test_" && String.is_suffix f ~suffix:".ml")
     |> List.sort ~compare:String.compare
     |> List.map ~f:(fun f -> dir ^ "/" ^ f))

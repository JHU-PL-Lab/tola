(** The project-test suite: each file's tests, and the tests that read the
    whole list. [canary project-test] runs [tests] after
    [Canary_project_test.all_tests]; [test_files] hands every file's tests
    to the overview page's §0.4. *)

open Base

(** A test file: what its tests are about, its path, its tests. *)
type file = string * string * Canary_project_test.pure_test list

let lib_file : file =
  ( "the project-definition layer", "src/canary/test/canary_project_test.ml",
    Canary_project_test.all_tests )

let subject_files : file list =
  [ ("the projects", "src/canary/main/canary_test_projects.ml", Canary_test_projects.tests);
    ("the overview page", "src/canary/main/canary_test_overview.ml", Canary_test_overview.tests);
    ("the run record", "src/canary/main/canary_test_record.ml", Canary_test_record.tests);
    ("the pipeline", "src/canary/main/canary_test_pipeline.ml", Canary_test_pipeline.tests);
    ("the run's environment", "src/canary/main/canary_test_env.ml", Canary_test_env.tests) ]

let base_tests : Canary_project_test.pure_test list =
  List.concat_map subject_files ~f:(fun (_, _, ts) -> ts)

let to_test_file ((subject, path, ts) : file) : Canary_overview_tests.file =
  { Canary_overview_tests.tf_subject = subject;
    tf_path = path;
    tf_tests =
      List.map ts ~f:(fun t ->
          { Canary_overview_tests.ts_name = t.Canary_project_test.name;
            ts_holds = t.Canary_project_test.holds }) }

(* [Canary_overview_looks.layout_rules] states each rule in words, with
   why and whose it is; a rule checked by a test names a test that exists,
   so the list cannot point at a renamed check. Defined after
   [base_tests] for that reason. Another drawing is held to the same
   rules by handing them its own positions ([layout_view]). See
   design/overview.md §5. *)
let layout_rules_pin : Canary_project_test.pure_test =
  { name = "overview.layout_rules_hold";
    holds = "The drawing keeps the layout's rules, and every rule a test checks names a registered test.";
    check =
      (fun () ->
        let module P = Canary_overview_looks in
        (not (List.is_empty P.layout_rules))
        && List.for_all P.layout_rules ~f:(fun r ->
               (not (String.is_empty r.P.lr_says))
               && (not (String.is_empty r.P.lr_why))
               &&
               match r.P.lr_check with
               | P.Places holds -> holds P.this_layout
               | P.Pinned_by name ->
                   List.exists base_tests ~f:(fun t ->
                       String.equal t.Canary_project_test.name name))
        (* the page shows the list *)
        && String.is_substring
             (Canary_overview_page.render Canary_registry.all_specs ~overview:"" ~generated_at:"pin")
             ~substring:{|id="jrules"|})
  }

(* A test left out of its subject's [tests] compiles and never runs. The
   scan reads every test record whose name is a literal; both ways of
   opening such a record must be found somewhere, so it cannot pass by
   finding nothing. *)
let written_pins_run_pin : Canary_project_test.pure_test =
  { name = "tests.every_written_pin_runs";
    holds = "Every test written in the test sources is registered, so it runs.";
    check =
      (fun () ->
        let registered =
          List.map (Canary_project_test.all_tests @ base_tests) ~f:(fun t ->
              t.Canary_project_test.name)
        in
        let written opening src =
          List.filter_map (String.substr_index_all src ~may_overlap:false ~pattern:opening)
            ~f:(fun i ->
              let from = i + String.length opening in
              Option.bind (String.index_from src from '"') ~f:(fun stop ->
                  let after =
                    String.lstrip
                      (String.sub src ~pos:(stop + 1)
                         ~len:(Int.min 64 (String.length src - stop - 1)))
                  in
                  let next = String.lstrip (String.drop_prefix after 1) in
                  if
                    String.is_prefix after ~prefix:";"
                    && (String.is_prefix next ~prefix:"holds" || String.is_prefix next ~prefix:"check")
                  then Some (String.sub src ~pos:from ~len:(stop - from))
                  else None))
        in
        let sources =
          List.map (Canary_test_fixtures.test_sources ()) ~f:(fun p ->
              Stdlib.In_channel.with_open_bin p Stdlib.In_channel.input_all)
        in
        let found =
          List.map [ {|{ name = "|}; {|{ Canary_project_test.name = "|} ] ~f:(fun opening ->
              List.concat_map sources ~f:(written opening))
        in
        let unrun =
          List.filter (List.concat found) ~f:(fun n ->
              not (List.mem registered n ~equal:String.equal))
        in
        List.iter unrun ~f:(Fmt.pr "    written, never run: %s@.");
        List.for_all found ~f:(Fn.non List.is_empty) && List.is_empty unrun)
  }

(* The suite's own tests read the whole list and are on it, hence [rec]. *)
let rec suite : Canary_project_test.pure_test list =
  [ layout_rules_pin; written_pins_run_pin; holds_said_pin; tests_listed_pin ]

and files () : file list =
  (lib_file :: subject_files) @ [ ("the suite itself", "src/canary/main/canary_tests.ml", suite) ]

(* The sentence is what the page lists for the test, so it is one line,
   ends as a sentence and fits a table cell. *)
and holds_said_pin : Canary_project_test.pure_test =
  { name = "tests.every_pin_says_what_it_holds";
    holds = "Every test states the claim it holds in one sentence.";
    check =
      (fun () ->
        let bad =
          List.filter
            (List.concat_map (files ()) ~f:(fun (_, _, ts) -> ts))
            ~f:(fun t ->
              let h = t.Canary_project_test.holds in
              String.is_empty h || String.contains h '\n'
              || (not (String.is_suffix h ~suffix:"."))
              || String.length h > 200)
        in
        List.iter bad ~f:(fun t ->
            Fmt.pr "    %s holds %S@." t.Canary_project_test.name t.Canary_project_test.holds);
        List.is_empty bad)
  }

(* Each file's block holds exactly its own tests, each with its claim
   after its name; the table counts them; and every name Figure 1 holds a
   box by is a test on the list, a test of the framework suites
   (artifact-test, pm-test, which §0.4 does not list) or a make target. *)
and tests_listed_pin : Canary_project_test.pure_test =
  { name = "overview.tests_lists_every_test";
    holds = "§0.4 lists every test project-test runs once, under its file and with its claim, and each test Figure 1 names is listed there or is a framework test.";
    check =
      (fun () ->
        let module O = Canary_overview_tests in
        let esc = Canary_overview_assets.esc in
        let fs = List.map (files ()) ~f:to_test_file in
        let blocks =
          List.drop (String.split (String.substr_replace_all (O.lists fs) ~pattern:"<details" ~with_:"\x00") ~on:'\x00') 1
        in
        let entry (t : O.test) =
          Printf.sprintf {|<dt id="%s"><code>%s</code></dt><dd>%s|} (esc (O.anchor t.O.ts_name))
            (esc t.O.ts_name) (esc t.O.ts_holds)
        in
        let listed =
          List.length blocks = List.length fs
          && List.for_all2_exn blocks fs ~f:(fun block (f : O.file) ->
                 List.length (String.substr_index_all block ~may_overlap:false ~pattern:"<dt ")
                 = List.length f.O.tf_tests
                 && List.for_all f.O.tf_tests ~f:(fun t ->
                        String.is_substring block ~substring:(entry t)))
        in
        let table = O.table fs in
        let counted =
          List.for_all fs ~f:(fun (f : O.file) ->
              String.is_substring table
                ~substring:
                  (Printf.sprintf "<td><code>%s</code></td><td>%d</td>" (esc f.O.tf_path)
                     (List.length f.O.tf_tests)))
        in
        let names = List.concat_map fs ~f:(fun f -> List.map f.O.tf_tests ~f:(fun t -> t.O.ts_name)) in
        let framework =
          String.concat
            (List.map
               [ "src/canary/test/canary_artifact_test.ml"; "src/canary/test/canary_pm_test.ml" ]
               ~f:(fun p -> Stdlib.In_channel.with_open_bin p Stdlib.In_channel.input_all))
        in
        let figure_ok =
          List.for_all Canary_overview_flow.boxes ~f:(fun b ->
              List.for_all b.Canary_overview_flow.bx_held ~f:(fun h ->
                  String.is_prefix h ~prefix:"make "
                  || List.mem names h ~equal:String.equal
                  || String.is_substring framework ~substring:(Printf.sprintf {|"%s"|} h)))
        in
        listed && counted && figure_ok)
  }

(** Every file's tests, for the overview page's §0.4. *)
let test_files () : Canary_overview_tests.file list = List.map (files ()) ~f:to_test_file

let tests : Canary_project_test.pure_test list = base_tests @ suite

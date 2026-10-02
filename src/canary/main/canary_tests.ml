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

(* [Canary_overview_looks.layout_rules] states each rule in words. Another
   drawing is held to the same rules by handing them its own positions
   ([layout_view]). See design/overview.md §5. *)
let layout_rules_test : Canary_project_test.pure_test =
  { name = "overview.layout_rules_hold";
    holds = "Every layout rule checked over places holds over this drawing's positions, and the page shows the list of rules.";
    check =
      (fun () ->
        let module P = Canary_overview_looks in
        (not (List.is_empty P.layout_rules))
        && List.for_all P.layout_rules ~f:(fun r ->
               match r.P.lr_check with
               | P.Places holds -> holds P.this_layout
               | P.Tested_by _ -> true)
        (* the page shows the list *)
        && String.is_substring
             (Canary_overview_page.render Canary_registry.all_specs ~overview:"" ~generated_at:"test")
             ~substring:{|id="jrules"|})
  }

(* The suite's own tests read the whole list and are on it, hence [rec]. *)
let rec suite : Canary_project_test.pure_test list =
  [ layout_rules_test; tests_listed_test ]

and files () : file list =
  (lib_file :: subject_files) @ [ ("the suite itself", "src/canary/main/canary_tests.ml", suite) ]

(* Each file's block holds exactly its own tests, each with its claim
   after its name, and the table counts them. *)
and tests_listed_test : Canary_project_test.pure_test =
  { name = "overview.tests_lists_every_test";
    holds = "§0.4 lists every test project-test runs once, under its file and with its claim, and its table counts each file's tests.";
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
        listed && counted)
  }

(** Every file's tests, for the overview page's §0.4. *)
let test_files () : Canary_overview_tests.file list = List.map (files ()) ~f:to_test_file

let tests : Canary_project_test.pure_test list = base_tests @ suite

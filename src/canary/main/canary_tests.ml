(** The project-test suite above canary_lib: each subject's pins, joined,
    and the two pins that read the whole list. [canary project-test] runs
    [tests] after [Canary_project_test.all_tests]. *)

open Base

let base_tests : Canary_project_test.pure_test list =
  Canary_test_projects.tests @ Canary_test_overview.tests @ Canary_test_record.tests
  @ Canary_test_pipeline.tests @ Canary_test_env.tests

(* The drawing keeps the layout's rules. [Canary_overview_looks.layout_rules]
   states each rule in words, with why and whose it is; every rule checked
   over places holds over this layout's, and every rule checked by a pin
   names a pin that exists, so the list cannot point at a renamed check.
   Defined after [base_tests] for that reason. Another drawing is held to
   the same rules by handing them its own positions ([layout_view]). *)
let layout_rules_pin : Canary_project_test.pure_test =
  { name = "overview.layout_rules_hold";
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

(* Every pin written runs: every pin record in the test sources whose
   name is a literal is registered, since a pin left out of its subject's
   [tests] compiles and never runs. Both ways of opening such a record
   must be found somewhere, so the scan cannot pass by finding nothing. *)
let written_pins_run_pin : Canary_project_test.pure_test =
  { name = "tests.every_written_pin_runs";
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
                  if
                    String.is_prefix after ~prefix:";"
                    && String.is_prefix (String.lstrip (String.drop_prefix after 1))
                         ~prefix:"check"
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

let tests : Canary_project_test.pure_test list =
  base_tests @ [ layout_rules_pin; written_pins_run_pin ]

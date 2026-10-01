(** The project-test suite above canary_lib: each subject's pins, joined,
    and the two pins that read the whole list. [canary project-test] runs
    [tests] after [Canary_project_test.all_tests]. *)

open Base

let base_tests : Canary_project_test.pure_test list =
  Canary_test_projects.tests @ Canary_test_overview.tests @ Canary_test_record.tests
  @ Canary_test_pipeline.tests @ Canary_test_env.tests

(* [Canary_overview_looks.layout_rules] states each rule in words, with
   why and whose it is; a rule checked by a pin names a pin that exists,
   so the list cannot point at a renamed check. Defined after
   [base_tests] for that reason. Another drawing is held to the same
   rules by handing them its own positions ([layout_view]). *)
let layout_rules_pin : Canary_project_test.pure_test =
  { name = "overview.layout_rules_hold";
    holds = "The drawing keeps the layout's rules, and every rule a pin checks names a registered pin.";
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

(* A pin left out of its subject's [tests] compiles and never runs. The
   scan reads every pin record whose name is a literal; both ways of
   opening such a record must be found somewhere, so it cannot pass by
   finding nothing. *)
let written_pins_run_pin : Canary_project_test.pure_test =
  { name = "tests.every_written_pin_runs";
    holds = "Every pin written in the test sources is registered, so it runs.";
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

(* The sentence is what the page lists for the pin, so it is one line,
   ends as a sentence and fits a table cell. *)
let holds_said_pin : Canary_project_test.pure_test =
  { name = "tests.every_pin_says_what_it_holds";
    holds = "Every pin states the claim it holds in one sentence.";
    check =
      (fun () ->
        let bad =
          List.filter
            (Canary_project_test.all_tests @ base_tests @ [ layout_rules_pin; written_pins_run_pin ])
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

let tests : Canary_project_test.pure_test list =
  base_tests @ [ layout_rules_pin; written_pins_run_pin; holds_said_pin ]

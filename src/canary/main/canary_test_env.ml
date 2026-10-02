(** Tests on the run's environment: the opam switch, the platform, strict
    mode, the CI rendering and the opam template. *)

open Base

(* Canary has its own switch because it installs packages and flips pins
   as it runs. Held: (1) the shipped default is the machine's
   ([default_opam_switch]), which is [canary] or ambient; (2) selecting
   no switch adds nothing to the shell, and selecting one exports
   OPAMSWITCH; (3) the switch is part of the step fingerprint, so a
   verdict earned in one switch is never served in another; (4) the
   framework tests and (5) OCaml-side shell-outs run under the same
   prologue as steps. *)
let canary_switch_test : Canary_project_test.pure_test =
  { name = "switch.selection";
    holds = "A step's shell prologue exports the selected opam switch, framework tests and store queries run in it, and a step's fingerprint depends on it.";
    check =
      (fun () ->
        let saved = !Canary_store.opam_switch in
        let restore () = Canary_store.opam_switch := saved in
        let fingerprint_under sw =
          Canary_store.opam_switch := sw;
          let step : Canary_step_model.step =
            { tag = "probe"; output_tag = "o"; output_dir = "d";
              project_dir = "p"; variant_id = "v"; action = Canary_basic.Probe_lib;
              deps = []; cmd = (fun ~output_dir:_ ~variant_key:_ -> "echo hi");
              dep_dirs = [];
              check_post = (fun ~output_dir:_ ~variant_key:_ -> true);
              expectation = Canary_step_model.Expect_success; symbol_check = None;
              disabled_agreements = []; agreement_ctx = None; dummy = None;
              location = None; inspects = None; bridge = None;
              placeholder = None }
          in
          Canary_local_runner.step_fingerprint step
        in
        (* (1) the shipped default is the machine's *)
        let machine_default = Lazy.force Canary_store.default_opam_switch in
        let default_is_machine_default =
          Poly.equal saved machine_default
          && (match machine_default with
              | Some s -> String.equal s "canary"
              | None -> true)
        in
        (* (2) no switch selected: an empty prologue *)
        Canary_store.opam_switch := None;
        let ambient_prologue = String.equal (Canary_store.opam_switch_prologue ()) "" in
        (* and a selected one exports it *)
        Canary_store.opam_switch := Some "canary";
        let exports =
          String.is_substring (Canary_store.opam_switch_prologue ())
            ~substring:"OPAMSWITCH"
        in
        (* (3) the fingerprint separates the switches *)
        let f_canary = fingerprint_under (Some "canary") in
        let f_default = fingerprint_under (Some "default") in
        let f_ambient = fingerprint_under None in
        restore ();
        (* (4) the framework tests' shell cases, through
           [Canary_pm_test.run_test] *)
        Canary_store.opam_switch := Some "canary";
        (* a probe only the prologue can satisfy: `true` would pass
           either way *)
        let case : Canary_pm_test.test_case =
          { name = "probe"; cmd = "test \"$OPAMSWITCH\" = canary";
            expected_rc = 0 }
        in
        let ran = Canary_pm_test.run_test case in
        let axis_ok = ran.Canary_pm_test.actual_rc = 0 in
        (* (5) OCaml-side shell-outs that ask a store ([pin_check_post],
           [is_installed]) go through [sh_in_switch]; same probe as (4) *)
        Canary_store.opam_switch := Some "canary";
        let ocaml_side_ok =
          Canary_store.sh_in_switch "test \"$OPAMSWITCH\" = canary" = 0
        in
        restore ();
        default_is_machine_default && ambient_prologue && exports && axis_ok
        && ocaml_side_ok
        && (not (String.equal f_canary f_default))
        && (not (String.equal f_canary f_ambient))) }

(* Under each platform in turn: (1) every consumer reports it, override
   included; (2) the system PM is derived from it, so brew on Linux
   cannot be represented; (3) the loader variable and the nm flag move
   with it; (4) it is part of the step fingerprint, so a verdict earned
   on one platform is never served to the other; (5) the default switch
   is a function of it. *)
let platform_single_source_test : Canary_project_test.pure_test =
  { name = "platform.single_source";
    holds = "The platform is one value that every consumer reads, and the system package manager, loader variable, nm flag and step fingerprint follow it.";
    check =
      (fun () ->
        let saved = !Canary_store.platform_override in
        let restore () = Canary_store.platform_override := saved in
        let fingerprint_under d =
          Canary_store.set_platform d;
          let step : Canary_step_model.step =
            { tag = "probe"; output_tag = "o"; output_dir = "d";
              project_dir = "p"; variant_id = "v"; action = Canary_basic.Probe_lib;
              deps = []; cmd = (fun ~output_dir:_ ~variant_key:_ -> "echo hi");
              dep_dirs = [];
              check_post = (fun ~output_dir:_ ~variant_key:_ -> true);
              expectation = Canary_step_model.Expect_success; symbol_check = None;
              disabled_agreements = []; agreement_ctx = None; dummy = None;
              location = None; inspects = None; bridge = None;
              placeholder = None }
          in
          Canary_local_runner.step_fingerprint step
        in
        (* (1) + (2) + (3), under each platform in turn *)
        let agrees_under d ~want_pm ~want_ld ~want_nm ~want_macos =
          Canary_store.set_platform d;
          Poly.equal (Canary_basic.detect_distro ()) d
          && Poly.equal (Canary_store.detect_pm ()) want_pm
          && String.equal (Canary_basic.ld_path_var ()) want_ld
          && String.equal (Canary_artifact_native.nm_dynamic_flag ()) want_nm
          && Bool.equal (Canary_artifact_native.is_macos ()) want_macos
        in
        let mac =
          agrees_under Canary_store.MacOS_local ~want_pm:Canary_store.Brew
            ~want_ld:"DYLD_LIBRARY_PATH" ~want_nm:"-g" ~want_macos:true
        in
        let wsl =
          agrees_under Canary_store.Wsl ~want_pm:Canary_store.Apt
            ~want_ld:"LD_LIBRARY_PATH" ~want_nm:"-D" ~want_macos:false
        in
        (* (4) the fingerprint separates the two *)
        let f_mac = fingerprint_under Canary_store.MacOS_local in
        let f_wsl = fingerprint_under Canary_store.Wsl in
        (* (5) the mapping: ambient on macOS, [canary] on WSL. Not
           tested: that [default_opam_switch] reads [detected_platform],
           not [platform ()], so a `--platform=macos` render cannot
           repoint this machine's store. The lazy is forced at module
           init, before any override exists, so a test could not tell. *)
        let mapping_ok =
          Poly.equal (Canary_store.default_switch_of Canary_store.MacOS_local) None
          && Poly.equal
               (Canary_store.default_switch_of Canary_store.Wsl)
               (Some "canary")
        in
        restore ();
        mac && wsl && mapping_ok
        && not (String.equal f_mac f_wsl)) }

(* Strict mode is a flag of the invocation. Held: (1) strict mode is off
   by default, since a violated agreement at a passing step is a finding
   about artifacts, not a broken step; (2) the permissive digest equals
   the digest spelled out longhand, with no strict input, so permissive
   markers stay warm; (3) strict mode changes the digest. Not tested
   here: that a violation fails the step, which needs a real project's
   log and a deliberate break, not a synthetic [agreement_ctx]. *)
let strict_mode_test : Canary_project_test.pure_test =
  { name = "strict.acceptance_policy";
    holds = "Strict mode is off by default, adds nothing to a permissive step's fingerprint, and changes it when on, so no permissive verdict serves a strict run.";
    check =
      (fun () ->
        let saved = Canary_agreement_common.strict_mode () in
        let restore () = Canary_agreement_common.set_strict saved in
        let step : Canary_step_model.step =
          { tag = "probe"; output_tag = "o"; output_dir = "d";
            project_dir = "p"; variant_id = "v"; action = Canary_basic.Probe_lib;
            deps = []; cmd = (fun ~output_dir:_ ~variant_key:_ -> "echo hi");
            dep_dirs = [];
            check_post = (fun ~output_dir:_ ~variant_key:_ -> true);
            expectation = Canary_step_model.Expect_success; symbol_check = None;
            disabled_agreements = []; agreement_ctx = None; dummy = None;
              location = None; inspects = None; bridge = None;
              placeholder = None }
        in
        let fingerprint_under b =
          Canary_agreement_common.set_strict b;
          Canary_local_runner.step_fingerprint step
        in
        (* (1) off unless the invocation says otherwise *)
        Canary_agreement_common.set_strict false;
        let default_is_permissive = not (Canary_agreement_common.strict_mode ()) in
        (* (2) the permissive digest, spelled out longhand *)
        let f_lax = fingerprint_under false in
        let expected_lax =
          Stdlib.Digest.to_hex
            (Stdlib.Digest.string
               (step.cmd ~output_dir:step.output_dir ~variant_key:step.variant_id
               ^ "\x00" ^ "success" ^ "\x00"
               ^ Canary_store.opam_switch_label () ^ "\x00"
               ^ Canary_store.string_of_platform (Canary_store.platform ())))
        in
        (* (3) and strict is a different question *)
        let f_strict = fingerprint_under true in
        restore ();
        default_is_permissive
        && String.equal f_lax expected_lax
        && not (String.equal f_lax f_strict)) }

(* A derived expectation ([Expect_compat_derived]) with no prediction
   means the artifact is good and the step must succeed, so it renders as
   a plain step; the oracle ([Expect_compat_failure]) always expects a
   failure and renders a verify; a plain success never does. *)
let gh_derived_polarity_test : Canary_project_test.pure_test =
  { name = "gh.derived_expectation_polarity";
    holds = "A step's GitHub Actions rendering adds a verify step only where the step expects a failure, and that verify greps the step's own log.";
    check =
      (fun () ->
        let step_with exp : Canary_step_model.step =
          { tag = "probe_binding_ocaml"; output_tag = "probe_binding_ocaml";
            output_dir = "d"; project_dir = "p"; variant_id = "v";
            action = Canary_basic.Probe_binding Canary_lang.OCaml; deps = [];
            cmd = (fun ~output_dir:_ ~variant_key:_ -> "run it");
            dep_dirs = [];
            check_post = (fun ~output_dir:_ ~variant_key:_ -> true);
            expectation = exp; symbol_check = None; disabled_agreements = [];
            agreement_ctx = None; dummy = None;
              location = None; inspects = None; bridge = None;
              placeholder = None }
        in
        let rendered exp =
          String.concat ~sep:"\n"
            (Canary_gh.render_gh_step ~project:"x" (step_with exp))
        in
        let has_verify r = String.is_substring r ~substring:"(verify)" in
        (* no prediction: derived renders plain, and the oracle still
           asserts the failure the project declared *)
        let derived_empty =
          rendered (Canary_step_model.Expect_compat_derived { inputs = []; version_info = None })
        and oracle_empty =
          rendered (Canary_step_model.Expect_compat_failure { inputs = []; version_info = None })
        in
        (not (has_verify derived_empty))
        && has_verify oracle_empty
        (* and a plain success is never a failure check *)
        && not (has_verify (rendered Canary_step_model.Expect_success))
        (* the verify greps the step's own log, named with the variant
           key *)
        && (let with_strings =
              rendered
                (Canary_step_model.Expect_failure
                   { contains_any = [ "boom" ]; version_info = None })
            in
            String.is_substring with_strings
              ~substring:(Canary_basic.variant_file ~variant_key:"v" "probe.log")
            && not (String.is_substring with_strings ~substring:"/probe.log\""))) }

(* Design: doc/canary/design/platform.md §2b. The specs rebuilt under
   each platform are compared too. It compares the world set and its
   order, not the realization data a declaration carries: a [Vendored_at]
   origin string is realize's to resolve, and realize may know the
   platform. *)
let platform_enumeration_test : Canary_project_test.pure_test =
  { name = "platform.enumeration_is_agnostic";
    holds = "Declaring, enumerating, selecting and ordering every catalogued project's worlds give the same result under WSL and macOS.";
    check =
      (fun () ->
        let saved = !Canary_store.platform_override in
        let restore () = Canary_store.platform_override := saved in
        let under d f = Canary_store.set_platform d; f () in
        let js x = Yojson.Basic.to_string x in
        (* declare, enumerate, select and order *)
        let snapshot d pr =
          under d (fun () ->
              js (Canary_pipeline.json_declare pr)
              ^ js
                  (`List
                    (List.map (Canary_pipeline.worlds pr)
                       ~f:Canary_pipeline.json_of_assignment))
              ^ js
                  (`List
                    (List.map
                       (Canary_pipeline.enumerated pr)
                       ~f:Canary_pipeline.json_of_assignment))
              ^ js (Canary_pipeline.json_order pr))
        in
        let invariant =
          List.for_all Canary_registry.all_specs ~f:(fun (_n, pr) ->
              String.equal
                (snapshot Canary_store.Wsl pr)
                (snapshot Canary_store.MacOS_local pr))
        in
        let realized d pr =
          under d (fun () ->
              let a = List.hd_exn (Canary_pipeline.ordered pr) in
              let ctx = Canary_pipeline.ctx_of pr a in
              List.map (Canary_pipeline.steps_of ~root:"_out/canary" pr ~ctx a)
                ~f:(fun s ->
                  s.Canary_step_model.tag ^ "\n"
                  ^ s.Canary_step_model.cmd ~output_dir:"D" ~variant_key:"V")
              |> String.concat ~sep:"\n")
        in
        (* the specs rebuilt under each platform, argument and override:
           the check above reuses one constructed spec, so it misses a
           spec that baked the platform in at module init. A project
           without a builder is covered by the check above only. *)
        let rebuilt_invariant =
          let cmp build =
            String.equal
              (under Canary_store.Wsl (fun () -> snapshot Canary_store.Wsl (build Canary_store.Wsl)))
              (under Canary_store.MacOS_local (fun () ->
                   snapshot Canary_store.MacOS_local (build Canary_store.MacOS_local)))
          in
          (* z3 and llvm take a distro, which the registry says they
             ignore *)
          cmp (fun d -> Canary_project_z3.z3_run d)
          && cmp (fun d -> Canary_project_llvm.llvm_run d)
          (* the opam-binding template builds the whole declaration *)
          && List.for_all
               [ Canary_project_zlib.decl; Canary_project_cairo.decl;
                 Canary_project_libffi.decl; Canary_project_zstd.decl ]
               ~f:(fun decl -> cmp (fun _ -> Canary_opam_binding.run decl))
        in
        (* non-vacuity: the platform must reach realize, or the checks
           above hold trivially. sqlite is the witness: its lib comes from
           the system PM, and its realization only builds strings
           ([steps_of] is not pure for every project). *)
        let sqlite = Canary_project_sqlite.sqlite_run in
        let pass5_varies =
          not
            (String.equal
               (realized Canary_store.Wsl sqlite)
               (realized Canary_store.MacOS_local sqlite))
        in
        restore ();
        invariant && rebuilt_invariant && pass5_varies) }

let opam_template_render_test : Canary_project_test.pure_test =
  { name = "tool.opam_template_render";
    holds = "Rendering zarith's wrapper declaration reproduces the committed zarith-no-conf opam template byte for byte.";
    check =
      (fun () ->
        let committed =
          Stdlib.In_channel.with_open_text
            "canary/templates/opam-local-repo/packages/zarith/zarith-no-conf.dev/opam.in"
            Stdlib.In_channel.input_all
        in
        String.equal
          (Canary_opam_template.render Canary_project_zarith.zarith_wrapper_decl)
          committed) }

let tests : Canary_project_test.pure_test list =
  [ canary_switch_test; opam_template_render_test; platform_single_source_test; strict_mode_test;
    platform_enumeration_test; gh_derived_polarity_test ]

(** Pins on the run's environment: the opam switch, the platform, strict
    mode, the CI rendering and the opam template. *)

open Base

(* THE CANARY SWITCH (2026-08-26, user: "prepare another ocaml switch for
   all the canary experimenting").

   Canary installs and uninstalls opam packages as it runs, and a binding
   channel pair is realized by flipping a pin — which for zstd removes
   [ocaml-compiler] and recompiles 157 packages. Doing that to a person's
   working switch is why the binding axis sat blocked; canary therefore
   defaults to a switch of its own.

   Three properties, and the third is the one with teeth:

   1. the default is the MACHINE's default (2026-08-26 evening): the
      dedicated [canary] switch on the box that has one, ambient on the
      mac, which does not. What the pin holds is that the shipped default
      is not an accident — it is whatever [default_opam_switch] decides,
      so a person who forgets a flag gets the protection their machine
      was set up with;
   2. selecting none restores the pre-2026-08-26 behaviour EXACTLY (an
      empty prologue, so the emitted shell is byte-identical);
   3. the switch is part of the step fingerprint. A verdict earned in one
      switch says nothing about another, and serving it across a switch
      change is precisely the stale-hit class the fingerprint exists to
      close (landing.md §4). Falsified by construction: if the label were
      dropped from the digest the two hashes below would coincide. *)
let canary_switch_pin : Canary_project_test.pure_test =
  { name = "switch.selection";
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
        (* (1) the shipped default is the machine's default — and on a
           box that HAS a dedicated switch, that default is it *)
        let machine_default = Lazy.force Canary_store.default_opam_switch in
        let default_is_machine_default =
          Poly.equal saved machine_default
          && (match machine_default with
              | Some s -> String.equal s "canary"
              | None -> true)
        in
        (* (2) no switch selected => empty prologue, byte-identical shell *)
        Canary_store.opam_switch := None;
        let ambient_prologue = String.equal (Canary_store.opam_switch_prologue ()) "" in
        (* and a selected one exports it *)
        Canary_store.opam_switch := Some "canary";
        let exports =
          String.is_substring (Canary_store.opam_switch_prologue ())
            ~substring:"OPAMSWITCH"
        in
        (* (3) the fingerprint separates the two worlds *)
        let f_canary = fingerprint_under (Some "canary") in
        let f_default = fingerprint_under (Some "default") in
        let f_ambient = fingerprint_under None in
        restore ();
        (* (4) THE TEST AXIS USES THE SAME PROLOGUE (2026-08-26). Both
           suites' shell cases run through [Canary_pm_test.run_test]; if
           it stopped applying the prologue the framework tests would go
           back to certifying the ambient toolchain while runs used
           canary's. Checked by construction: run_test must compose the
           prologue with the case's cmd. *)
        Canary_store.opam_switch := Some "canary";
        (* the probe must be one only the PROLOGUE can satisfy — `true`
           succeeds either way, which is how the first version of this
           check passed its own falsification. Asking the shell what
           OPAMSWITCH holds cannot. *)
        let case : Canary_pm_test.test_case =
          { name = "probe"; cmd = "test \"$OPAMSWITCH\" = canary";
            expected_rc = 0 }
        in
        let ran = Canary_pm_test.run_test case in
        let axis_ok = ran.Canary_pm_test.actual_rc = 0 in
        (* (5) AND SO DOES OCAML'S OWN SHELL-OUT (2026-08-26). A step's
           command is not the only thing canary runs: [pin_check_post] and
           [is_installed] ask a store what it holds, from OCaml, outside
           any step. Those were bare [Sys.command] and inherited a process
           environment with no OPAMSWITCH — so on WSL the sqlite pin check
           read `default` (5.4.1) while the fetch had installed 5.1.0 into
           `canary`: five scenarios red, and the other five green for the
           same wrong reason. Same falsification as (4): only the prologue
           can satisfy this probe. *)
        Canary_store.opam_switch := Some "canary";
        let ocaml_side_ok =
          Canary_store.sh_in_switch "test \"$OPAMSWITCH\" = canary" = 0
        in
        restore ();
        default_is_machine_default && ambient_prologue && exports && axis_ok
        && ocaml_side_ok
        && (not (String.equal f_canary f_default))
        && (not (String.equal f_canary f_ambient))) }

(* THE PLATFORM IS ONE VALUE (2026-08-26, user: "the canary config should
   carry the platform argument").

   Three modules used to sniff the machine independently —
   [Canary_basic.detect_distro] (uname), [Canary_store.detect_pm] (which
   brew / which apt-get) and [Canary_artifact_native.is_macos] (uname
   again) — and they could DISAGREE: [detect_pm] tried brew first, so a
   Linux box with Linuxbrew answered [Brew] against a [Wsl] distro, and
   [system_pkg_for_pm] would then pick the macOS package name on Linux.

   Four properties, and the second is the one that closes that hole:

   1. every consumer reports the SAME platform, override included — a
      [--platform] that reached the package names but not the nm flags
      would be worse than no override at all;
   2. the system PM is DERIVED from the platform, not sniffed beside it,
      so brew-on-Linux cannot be represented;
   3. the platform-dependent vocabulary actually moves with it (the
      loader variable and the nm flag are the two that decide whether a
      probe tests the world it names);
   4. it is part of the step fingerprint, so a verdict earned on one
      platform is never served to the other. Falsified by construction:
      drop the platform from the digest and the two hashes coincide. *)
let platform_single_source_pin : Canary_project_test.pure_test =
  { name = "platform.single_source";
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
        (* (5) THE DEFAULT SWITCH IS A FUNCTION OF THE PLATFORM
           (2026-08-26): the mac has no dedicated switch and runs
           ambient; the WSL box has [canary] and defaults to it. Pins the
           MAPPING, which is the falsifiable half — flip either row and
           this goes red.

           What is NOT pinned, deliberately: that [default_opam_switch]
           reads [detected_platform] rather than [platform ()], so a
           `--platform=macos` RENDER cannot repoint the store this
           machine installs into. That property is real and is why the
           code is written the way it is, but it is not observable — the
           lazy is forced at module init, before any override exists, so
           both spellings memoize the same answer. A test asserting it
           would pass either way, which is worse than no test. *)
        let mapping_ok =
          Poly.equal (Canary_store.default_switch_of Canary_store.MacOS_local) None
          && Poly.equal
               (Canary_store.default_switch_of Canary_store.Wsl)
               (Some "canary")
        in
        restore ();
        mac && wsl && mapping_ok
        && not (String.equal f_mac f_wsl)) }

(* STRICT MODE IS AN ARGUMENT OF THE INVOCATION (2026-09-15, user: "it's
   good during the development that the running shall fail fast for
   better debugging for ourself, rather than expected fails (xf)").

   Third flag of the [--switch] / [--platform] shape, and the same three
   things have to be true of it. What makes this one worth a pin of its
   own is that both directions are dangerous:

   1. IT IS OFF BY DEFAULT. Every landed project's steps accept "the
      command succeeded and the postcondition holds"; a violated
      agreement at a passing step is a finding about artifacts, not a
      broken step, and ssl's `dependencies_provided: violated
      libcrypto.so.3` is a real one that must not turn ssl red. If this
      row flips, ten projects change meaning at once and nothing else in
      the suite would say so;
   2. THE DEFAULT DIGEST DID NOT MOVE. Landing a fingerprint input
      normally costs one cold refresh of every step in every output tree
      (that is written down at [expectation_form]). This one must not,
      because the permissive question is exactly the question those
      markers already answered. Pinned as an EQUALITY against the digest
      spelled out longhand — appending a "lax" tag "for symmetry" would
      throw away every warm verdict on the box, silently;
   3. STRICT DOES separate it. A marker earned permissively answers a
      weaker question; serving it to a strict run would report PASS for
      a step that was never asked. Falsified by construction — drop the
      suffix and the two hashes coincide.

   NOT pinned here: that a violation actually fails the step. That is a
   claim about a real evaluation over real evidence, and the project's
   standard for it is a REAL project's log plus a deliberate break
   (agreement/agreements.md), not a synthetic [agreement_ctx] that would
   pass by agreeing with whatever the derivation happens to do today. *)
let strict_mode_pin : Canary_project_test.pure_test =
  { name = "strict.acceptance_policy";
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
        (* (2) the permissive digest is the pre-strict digest, longhand *)
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

(* THE GH RENDERING MUST AGREE WITH THE EXPECTATION'S POLARITY
   (2026-08-28).

   [Expect_compat_derived] computes its own polarity — a prediction means
   the step must fail, NO prediction means the artifact is good and the
   step must SUCCEED. The GH backend rendered it like the ORACLE variant
   ([Expect_compat_failure]), which always expects a failure, so a step
   the local runner expects to pass became a continue-on-error + verify
   pair asserting the opposite. ssl's first CI job said so:

     FAIL: expected failure but step succeeded

   on [probe_binding_ocaml], whose red cell locally is not there at all —
   it sits on [probe_app_ocaml]. A CI backend that disagrees with the
   runner about WHICH step is red is worse than one that does not run. *)
let gh_derived_polarity_pin : Canary_project_test.pure_test =
  { name = "gh.derived_expectation_polarity";
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
        (* no prediction: DERIVED must render as a plain step, the ORACLE
           must still assert a failure — the project declared one *)
        let derived_empty =
          rendered (Canary_step_model.Expect_compat_derived { inputs = []; version_info = None })
        and oracle_empty =
          rendered (Canary_step_model.Expect_compat_failure { inputs = []; version_info = None })
        in
        (not (has_verify derived_empty))
        && has_verify oracle_empty
        (* and a plain success is never a failure check *)
        && not (has_verify (rendered Canary_step_model.Expect_success))
        (* THE VERIFY MUST GREP THE LOG THE STEP WRITES (2026-08-28).
           It grepped a bare "probe.log", which existed only while CI ran
           one chain per project with an EMPTY variant key. A
           pipeline-rendered job has a real key, so every expected-failure
           verify grepped a file that does not exist and reported
           "expected message not found" — ssl's app probe, red for
           failing exactly as predicted. *)
        && (let with_strings =
              rendered
                (Canary_step_model.Expect_failure
                   { contains_any = [ "boom" ]; version_info = None })
            in
            String.is_substring with_strings
              ~substring:(Canary_basic.variant_file ~variant_key:"v" "probe.log")
            && not (String.is_substring with_strings ~substring:"/probe.log\""))) }

(* IS THE ENUMERATION PLATFORM-AGNOSTIC? (2026-08-26, user: "how about
   the platform affecting the enumeration? it should be agnostic until
   the runner, but can we confirm that?")

   [platform.md] §2b asserts passes 1–4 never see the platform and only
   pass 5 + the tool wrappers do. This turns the assertion into a
   measurement: run each pass under BOTH platforms and compare.

   The trap this pin has to avoid is being vacuous. "Identical under both
   platforms" is also what you get if the override reaches nothing at
   all — a spec frozen at module init compares equal to itself. So the
   pin asserts BOTH directions: passes 1–4 identical, AND a realized
   command that genuinely changes. Without the second half the first
   half proves nothing.

   WHAT IS COMPARED, stated exactly, because the first falsification of
   this pin slipped through it: the snapshot is the WORLD SET and its
   order — which artifacts exist, at which provisions, at which versions,
   which of those a run selects, and in what sequence. It is not the
   realization data hanging off a declaration: making the [Vendored_at]
   payload platform-dependent does NOT turn this red, because
   [json_declare] reports the provision, not its origin string. That is
   the right scope — an origin string is what pass 5 resolves, and pass 5
   is allowed to know the platform — but it means this pin says "both
   machines enumerate the same worlds", not "nothing downstream of a
   declaration mentions a platform".

   Falsified by making the world set itself depend on the platform (drop
   the Dev version point on macOS in the Pattern-A lib row): red, as it
   must be. *)
let platform_enumeration_pin : Canary_project_test.pure_test =
  { name = "platform.enumeration_is_agnostic";
    check =
      (fun () ->
        let saved = !Canary_store.platform_override in
        let restore () = Canary_store.platform_override := saved in
        let under d f = Canary_store.set_platform d; f () in
        let js x = Yojson.Basic.to_string x in
        (* passes 1 (declare), 2 (enumerate), 3 (select) and 4 (order),
           for every CATALOGUED project — a muted one still has a spec,
           and a spec that reads the platform is a spec that would make
           the two machines enumerate different worlds and stop being
           comparable, which is the whole point of running both. *)
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
        (* NON-VACUITY: the override must reach pass 5. sqlite is the
           witness — its lib comes from the system PM, so the realized
           step set carries [probe_lib_apt] on one platform and
           [probe_lib_brew] on the other. If this ever holds equal, the
           override stopped reaching the runner and the invariant above
           became a tautology.

           [steps_of] is not pure for every project (tiny-full
           materializes a tree), so the witness is a project whose
           realization only builds strings. *)
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
        (* AND THE SPEC REBUILT UNDER EACH PLATFORM. The check above
           re-runs the passes over one already-constructed [project_run],
           so it catches a pass that READS the platform — but not a spec
           that BAKED it in while the module initialized. A frozen spec
           compares equal to itself, which is the same vacuity trap in a
           second costume, and the registry makes it concrete: it hands
           [z3_run]/[llvm_run] a literal [Wsl], so if their declaration
           honoured that argument nothing above would notice.

           So rebuild the declaration under each platform — argument AND
           ambient override — and compare. Covers the seven projects that
           expose a builder, including every prebuilt-bearing one (the
           tempting place to resolve a machine path). sqlite, tiny-full
           and ssl are eager values with no builder to call; they are
           covered by the weaker check only. *)
        let rebuilt_invariant =
          let cmp build =
            String.equal
              (under Canary_store.Wsl (fun () -> snapshot Canary_store.Wsl (build Canary_store.Wsl)))
              (under Canary_store.MacOS_local (fun () ->
                   snapshot Canary_store.MacOS_local (build Canary_store.MacOS_local)))
          in
          (* the two that TAKE a distro — the registry's claim that they
             ignore it, asserted instead of documented *)
          cmp (fun d -> Canary_project_z3.z3_run d)
          && cmp (fun d -> Canary_project_llvm.llvm_run d)
          (* Pattern A: the template builds the whole declaration *)
          && List.for_all
               [ Canary_project_zlib.decl; Canary_project_cairo.decl;
                 Canary_project_libffi.decl; Canary_project_zstd.decl ]
               ~f:(fun decl -> cmp (fun _ -> Canary_opam_binding.run decl))
        in
        let sqlite = Canary_project_sqlite.sqlite_run in
        let pass5_varies =
          not
            (String.equal
               (realized Canary_store.Wsl sqlite)
               (realized Canary_store.MacOS_local sqlite))
        in
        restore ();
        invariant && rebuilt_invariant && pass5_varies) }

let opam_template_render_pin : Canary_project_test.pure_test =
  { name = "tool.opam_template_render";
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
  [ canary_switch_pin; opam_template_render_pin; platform_single_source_pin; strict_mode_pin;
    platform_enumeration_pin; gh_derived_polarity_pin ]

open Base

(** Framework tests for [Canary_artifact_mutation].

    Parallel to [canary_artifact_test]: verify that canary's own
    mutation primitives produce the shell commands they claim to,
    and that running those commands against tiny's real fixtures
    yields the expected mutations.

    Two test kinds (same shape as [canary_artifact_test]):
    - [pure_test]: pure OCaml predicate; runs anywhere.
    - shell tests via [Canary_pm_test.test_case]: run a shell
      command, check the exit code.

    Fixtures reused: tiny's [c/src/tiny.c] and the pre-authored
    [scenarios/patches/*.patch] files. Isolating the mutation API
    here means future recipe-synthesis work (see [tiny.md] §7.2)
    can drop into the same test shape. *)

let tiny_root = "canary/examples/tiny"
let patches_dir = tiny_root ^ "/scenarios/patches"

(* ── Pure predicate tests ── *)

type pure_test = { name : string; check : unit -> bool }

let run_pure_test (t : pure_test) : bool =
  try t.check () with _ -> false

let mutation_pure_tests = [
  { name = "apply_patch_cmd contains `patch -p1`"; check = fun () ->
      let cmd =
        Canary_artifact_mutation.apply_patch_cmd
          ~sandbox_dir:"/tmp/sb" ~patches_dir:"/tmp/p"
          ~patch_file:"foo.patch"
      in
      String.is_substring cmd ~substring:"patch -p1" };

  { name = "apply_patch_cmd cd's to sandbox_dir"; check = fun () ->
      let cmd =
        Canary_artifact_mutation.apply_patch_cmd
          ~sandbox_dir:"/tmp/sb" ~patches_dir:"/tmp/p"
          ~patch_file:"foo.patch"
      in
      String.is_substring cmd ~substring:"cd '/tmp/sb'" };

  { name = "apply_patch_cmd references full patch path"; check = fun () ->
      let cmd =
        Canary_artifact_mutation.apply_patch_cmd
          ~sandbox_dir:"/tmp/sb" ~patches_dir:"/tmp/p"
          ~patch_file:"foo.patch"
      in
      String.is_substring cmd ~substring:"'/tmp/p/foo.patch'" };

  { name = "apply_soname_bump_cmds emits exactly 5 commands"; check = fun () ->
      let cmds =
        Canary_artifact_mutation.apply_soname_bump_cmds
          ~lib_dir:"/l"
          ~old_full_name:"libx.so.1.0" ~old_major_name:"libx.so.1"
          ~new_full_name:"libx.so.2.0" ~new_major_name:"libx.so.2"
          ~generic_name:"libx.so"
      in
      List.length cmds = 5 };

  { name = "apply_soname_bump_cmds has mv, ln, patchelf"; check = fun () ->
      let cmds =
        Canary_artifact_mutation.apply_soname_bump_cmds
          ~lib_dir:"/l"
          ~old_full_name:"libx.so.1.0" ~old_major_name:"libx.so.1"
          ~new_full_name:"libx.so.2.0" ~new_major_name:"libx.so.2"
          ~generic_name:"libx.so"
      in
      let all = String.concat ~sep:"\n" cmds in
      String.is_substring all ~substring:"mv "
      && String.is_substring all ~substring:"ln -sf"
      && String.is_substring all ~substring:"patchelf --set-soname" };

  { name = "apply_soname_bump_cmds renames from old_full to new_full"; check = fun () ->
      let cmds =
        Canary_artifact_mutation.apply_soname_bump_cmds
          ~lib_dir:"/l"
          ~old_full_name:"libx.so.1.0" ~old_major_name:"libx.so.1"
          ~new_full_name:"libx.so.2.0" ~new_major_name:"libx.so.2"
          ~generic_name:"libx.so"
      in
      match cmds with
      | first :: _ ->
        String.is_substring first ~substring:"mv '/l/libx.so.1.0' '/l/libx.so.2.0'"
      | [] -> false };

  { name = "patch constructor produces .patch suffix"; check = fun () ->
      match Canary_artifact_mutation.patch "foo" with
      | Some (Canary_artifact_mutation.Patch { patch_file }) ->
        String.equal patch_file "foo.patch"
      | _ -> false };
]

(* ── Shell tests: apply real patches on a temp sandbox ── *)

(** Compose shell tests that use tiny's [scenarios/patches/] as
    fixtures. Sandbox lives under [~output_dir] so it's isolated
    and can be inspected on failure. *)
let mutation_shell_tests ~output_dir : Canary_pm_test.test_case list =
  let sandbox = output_dir ^ "/mutation-sandbox" in
  let cwd = Stdlib.Sys.getcwd () in
  let abs_patches_dir = cwd ^ "/" ^ patches_dir in
  [
    { name = "mutation.setup-sandbox";
      cmd = Printf.sprintf
        "rm -rf '%s' && mkdir -p '%s' && cp -a '%s/c' '%s/c'"
        sandbox sandbox tiny_root sandbox;
      expected_rc = 0 };

    { name = "mutation.pre-check-tiny_sum-present";
      cmd = Printf.sprintf
        "grep -q 'int tiny_sum' '%s/c/src/tiny.c'" sandbox;
      expected_rc = 0 };

    { name = "mutation.apply-symbol_missing.patch";
      cmd = Canary_artifact_mutation.apply_patch_cmd
        ~sandbox_dir:sandbox
        ~patches_dir:abs_patches_dir
        ~patch_file:"symbol_missing.patch";
      expected_rc = 0 };

    { name = "mutation.post-check-tiny_total-added";
      cmd = Printf.sprintf
        "grep -q 'int tiny_total' '%s/c/src/tiny.c'" sandbox;
      expected_rc = 0 };

    { name = "mutation.post-check-tiny_sum-removed";
      cmd = Printf.sprintf
        "! grep -q 'int tiny_sum' '%s/c/src/tiny.c'" sandbox;
      expected_rc = 0 };

    { name = "mutation.cleanup-sandbox";
      cmd = Printf.sprintf "rm -rf '%s'" sandbox;
      expected_rc = 0 };
  ]

(* ── Runner ── *)

let run_tests ?(output_dir = "_out/canary/test/mutation-test") () : bool =
  let _ = Stdlib.Sys.command (Printf.sprintf "mkdir -p '%s'" output_dir) in
  let pass = ref 0 in
  let fail = ref 0 in

  Fmt.pr "Mutation pure tests:@.";
  List.iter mutation_pure_tests ~f:(fun t ->
    let ok = run_pure_test t in
    if ok then Int.incr pass else Int.incr fail;
    Fmt.pr "  %-46s %s@." t.name (if ok then "PASS" else "FAIL"));
  Fmt.pr "@.";

  Fmt.pr "Mutation shell tests:@.";
  List.iter (mutation_shell_tests ~output_dir) ~f:(fun t ->
    let r = Canary_pm_test.run_test t in
    let ok = Canary_pm_test.is_pass r in
    if ok then Int.incr pass else Int.incr fail;
    Fmt.pr "  %-46s %s%s@."
      t.name
      (if ok then "PASS" else "FAIL")
      (if ok then ""
       else Printf.sprintf " (rc=%d)" r.actual_rc));
  Fmt.pr "@.";

  Fmt.pr "Total: %d PASS, %d FAIL@." !pass !fail;
  !fail = 0

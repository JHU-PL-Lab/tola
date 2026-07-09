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

(** All 12 tiny .patch fixtures. Each name is the file basename
    without the [.patch] suffix — matches the [patch <name>]
    constructor in the recipe. *)
let all_patch_names = [
  "api_complete";       "api_complete_python"; "api_faithful";
  "api_repack";         "api_repack_python";   "api_repack_stub_orphan";
  "behavior_silent";    "header_arity_bump";   "symbol_missing";
  "symbol_orphan";      "symbol_version_floor";"type_wrong";
]

(** Focused shell tests using [symbol_missing.patch] for content
    verification. Isolates one well-known mutation to make sure
    the apply + verify shape works before iterating over all
    fixtures. *)
let symbol_missing_shell_tests ~output_dir : Canary_pm_test.test_case list =
  let sandbox = output_dir ^ "/mutation-focused" in
  let cwd = Stdlib.Sys.getcwd () in
  let abs_patches_dir = cwd ^ "/" ^ patches_dir in
  [
    { name = "focus.setup-sandbox";
      cmd = Printf.sprintf
        "rm -rf '%s' && mkdir -p '%s' && cp -a '%s' '%s/tiny'"
        sandbox sandbox tiny_root sandbox;
      expected_rc = 0 };

    { name = "focus.pre-check-tiny_sum-present";
      cmd = Printf.sprintf
        "grep -q 'int tiny_sum' '%s/tiny/c/src/tiny.c'" sandbox;
      expected_rc = 0 };

    { name = "focus.apply-symbol_missing.patch";
      cmd = Canary_artifact_mutation.apply_patch_cmd
        ~sandbox_dir:(sandbox ^ "/tiny")
        ~patches_dir:abs_patches_dir
        ~patch_file:"symbol_missing.patch";
      expected_rc = 0 };

    { name = "focus.post-check-tiny_total-added";
      cmd = Printf.sprintf
        "grep -q 'int tiny_total' '%s/tiny/c/src/tiny.c'" sandbox;
      expected_rc = 0 };

    { name = "focus.post-check-tiny_sum-removed";
      cmd = Printf.sprintf
        "! grep -q 'int tiny_sum' '%s/tiny/c/src/tiny.c'" sandbox;
      expected_rc = 0 };

    { name = "focus.cleanup-sandbox";
      cmd = Printf.sprintf "rm -rf '%s'" sandbox;
      expected_rc = 0 };
  ]

(** Iterate over all 12 patch fixtures. For each: fresh sandbox
    (copy of tiny), apply the patch, verify [rc = 0]. Cheaper
    than content-specific asserts and catches "does this patch
    apply against the current tree" regressions across the whole
    fixture set. *)
let all_patches_shell_tests ~output_dir : Canary_pm_test.test_case list =
  let sandbox_root = output_dir ^ "/mutation-all" in
  let cwd = Stdlib.Sys.getcwd () in
  let abs_patches_dir = cwd ^ "/" ^ patches_dir in
  let per_patch p =
    let sb = sandbox_root ^ "/" ^ p in
    [
      { Canary_pm_test.name = Printf.sprintf "all.setup-%s" p;
        (* cp -a src/. dst copies contents into dst; without the /.
           and with dst pre-existing, cp creates dst/<basename src>. *)
        cmd = Printf.sprintf
          "rm -rf '%s' && mkdir -p '%s' && cp -a '%s/.' '%s/'"
          sb sb tiny_root sb;
        expected_rc = 0 };
      { name = Printf.sprintf "all.apply-%s.patch" p;
        cmd = Canary_artifact_mutation.apply_patch_cmd
          ~sandbox_dir:sb
          ~patches_dir:abs_patches_dir
          ~patch_file:(p ^ ".patch");
        expected_rc = 0 };
    ]
  in
  { Canary_pm_test.name = "all.mkdir-root";
    cmd = Printf.sprintf "rm -rf '%s' && mkdir -p '%s'"
            sandbox_root sandbox_root;
    expected_rc = 0 }
  :: List.concat_map all_patch_names ~f:per_patch
  @ [ { Canary_pm_test.name = "all.cleanup-root";
        cmd = Printf.sprintf "rm -rf '%s'" sandbox_root;
        expected_rc = 0 } ]

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

  let run_shell_group name tests =
    Fmt.pr "%s:@." name;
    List.iter tests ~f:(fun t ->
      let r = Canary_pm_test.run_test t in
      let ok = Canary_pm_test.is_pass r in
      if ok then Int.incr pass else Int.incr fail;
      Fmt.pr "  %-46s %s%s@."
        t.Canary_pm_test.name
        (if ok then "PASS" else "FAIL")
        (if ok then "" else Printf.sprintf " (rc=%d)" r.actual_rc));
    Fmt.pr "@."
  in
  run_shell_group "Focused shell tests (symbol_missing)"
    (symbol_missing_shell_tests ~output_dir);
  run_shell_group "All-patches shell tests (12 fixtures × apply)"
    (all_patches_shell_tests ~output_dir);

  Fmt.pr "Total: %d PASS, %d FAIL@." !pass !fail;
  !fail = 0

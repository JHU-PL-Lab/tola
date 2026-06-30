(** Tiny scenario specs — OCaml port of
    [canary/examples/tiny/scenarios/scenarios.py:SCENARIOS].

    Phase B of the Python→OCaml migration (see
    [doc/canary/design/ssot.md] §9.1, [doc/canary/design/tiny_migration.md]).
    Data-only port: each entry of the Python SCENARIOS dict becomes a
    [scenario_spec] value. apply/revert logic lands in Phase C.

    Parity check: [canary tiny-scenarios] output must match
    [python3 scenarios.py list] line-for-line until Phase E retires
    the Python harness. *)

open Base

(** Per-step expected outcome. Mirrors the Python [expected] dict's
    string vocabulary:
    - [Ok] / [Fail] — build / probe step outcome
    - [Pass] / [Fail] — comparator outcome
    - [Skip] — step not exercised because an earlier step failed *)
type outcome = Ok | Fail | Pass | Skip

let string_of_outcome = function
  | Ok -> "ok"
  | Fail -> "fail"
  | Pass -> "pass"
  | Skip -> "skip"

(** Build target a patch perturbation should rebuild before probes
    run. Source patches under [c/] need a cmake rebuild; OCaml /
    Python source patches don't (canary rebuilds the binding itself). *)
type rebuild_target =
  | Rebuild_native_c
  | Rebuild_none

(** How a scenario mutates the live tree.
    - [Patch] applies [scenarios/patches/<patch_file>] as a unified diff.
    - [Soname_bump] renames the shared object + rewrites its SONAME
      (patchelf or byte surgery).
    Positive-coverage scenarios carry [None]. *)
type perturbation =
  | Patch of { patch_file : string; rebuild : rebuild_target }
  | Soname_bump of { from_so : string; to_so : string }

(** A complete scenario spec — the [ssot.md §9.2] one-time spec.
    Both tiny's perturbation engine and canary's variant enumeration
    read this once Phase D lands. *)
type scenario_spec = {
  name : string;
  description : string;
  violates : Canary_compat.contract_id list;
  perturbs : string list;
  perturbation : perturbation option;
  expected : (string * outcome) list;
}

(* ----- helpers ----- *)

let c_patch name =
  Some (Patch { patch_file = name ^ ".patch"; rebuild = Rebuild_native_c })

let ml_patch name =
  Some (Patch { patch_file = name ^ ".patch"; rebuild = Rebuild_none })

(* ----- the 15 scenarios (order = scenarios.py:SCENARIOS insertion order) ----- *)

let scenarios : scenario_spec list =
  let open Canary_compat in
  [
    { name = "symbol_missing";
      description =
        "Source patch renames tiny_sum -> tiny_total in C only; binding \
         artifacts still expect tiny_sum.";
      violates = [ C1 ];
      perturbs = [ "c/src/tiny.c" ];
      perturbation = c_patch "symbol_missing";
      expected = [
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Fail; "cmp_symbol_cext", Fail;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Skip;
        "cmp_api_complete_ctypes", Skip;
      ];
    };
    { name = "header_arity_bump";
      description =
        "tiny.h declares tiny_sum with an extra (int c) parameter; tiny.c \
         matches the new signature so the lib still builds. The cstub \
         calls tiny_sum(a, b) — only 2 args. c6 cmp_type catches the \
         static mismatch.";
      violates = [ C6 ];
      perturbs = [ "c/include/tiny.h"; "c/src/tiny.c" ];
      perturbation = c_patch "header_arity_bump";
      expected = [
        "ocaml_build", Fail; "ocaml_probe", Skip;
        "ocaml_app_binding", Skip; "ocaml_app_helper", Skip;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];
    };
    { name = "symbol_version_floor";
      description =
        "Lib's tiny.map version script is bumped from TINY_1.0 to TINY_2.0; \
         rebuild emits libtiny.so with tiny_sum@@TINY_2.0. Cached cext \
         records @TINY_1.0 in its NEEDED — dyld can't satisfy the version \
         tag at load time. c5 cmp_sym_version catches the mismatch.";
      violates = [ C5 ];
      perturbs = [ "c/tiny.map" ];
      perturbation = c_patch "symbol_version_floor";
      expected = [
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Fail; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];
    };
    { name = "abi_soname_bump";
      description =
        "SONAME bumped libtiny.so.1 -> libtiny.so.2 and file renamed; \
         binding NEEDED libtiny.so.1 has nothing to resolve against. \
         Symbols themselves unchanged.";
      violates = [ C4 ];
      perturbs = [ "c/build/libtiny.so.1" ];
      perturbation =
        Some (Soname_bump { from_so = "libtiny.so.1"; to_so = "libtiny.so.2.0" });
      expected = [
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Skip;
        "cmp_api_complete_ctypes", Skip;
      ];
    };
    { name = "type_wrong";
      description =
        "tiny_sum body takes (double, double); header still says (int, \
         int). Symbol names unchanged; no static comparator catches this \
         today.";
      violates = [ C6; C3 ];
      perturbs = [ "c/src/tiny.c" ];
      perturbation = c_patch "type_wrong";
      expected = [
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];
    };
    { name = "api_faithful";
      description =
        "C adds tiny_max; bindings don't wrap it. Build and probe all \
         succeed; no static comparator catches the missing wrapper (c8 \
         cmp_api_faithfulness doesn't exist yet).";
      violates = [ C8 ];
      perturbs = [ "c/include/tiny.h"; "c/src/tiny.c" ];
      perturbation = c_patch "api_faithful";
      expected = [
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];
    };
    { name = "api_repack";
      description =
        "OCaml user-facing Tiny.diff reverses arguments before delegating. \
         Stub-facing layer correct; intra-binding repack wrong; c7 \
         cmp_api_repack doesn't exist yet.";
      violates = [ C7; C3 ];
      perturbs = [ "ocaml/tiny.ml" ];
      perturbation = ml_patch "api_repack";
      expected = [
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];
    };
    { name = "api_complete";
      description =
        "OCaml user-facing Tiny.mli drops 'val sum'. The library still \
         compiles (tiny's dune sets -w -32) but every consumer that \
         references Tiny.sum fails at compile time. c2 \
         cmp_api_completeness statically catches the missing val.";
      violates = [ C2 ];
      perturbs = [ "ocaml/tiny.mli" ];
      perturbation = ml_patch "api_complete";
      expected = [
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Fail; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];
    };
    { name = "behavior_silent";
      description =
        "tiny_sum body computes a-b-tiny_offset instead of a+b+tiny_offset. \
         Every static contract still holds; only the running probe \
         notices. Canonical demonstration that c3 cmp_behavior is \
         non-redundant.";
      violates = [ C3 ];
      perturbs = [ "c/src/tiny.c" ];
      perturbation = c_patch "behavior_silent";
      expected = [
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];
    };
    { name = "symbol_orphan";
      description =
        "OCaml stub introduces a caml_tiny_extra wrapper that calls \
         tiny_extra; the C side never had tiny_extra. Dual of \
         symbol_missing. On strict linkers ocaml_build fails; on \
         permissive linkers only c1 catches it.";
      violates = [ C1 ];
      perturbs =
        [ "ocaml/tiny_raw.ml"; "ocaml/tiny_raw.mli"; "ocaml/tiny_stubs.c" ];
      perturbation = ml_patch "symbol_orphan";
      expected = [
        "ocaml_build", Fail; "ocaml_probe", Skip;
        "ocaml_app_binding", Skip; "ocaml_app_helper", Skip;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Fail; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];
    };
    { name = "api_repack_python";
      description =
        "Python user-facing layer (both cext and ctypes __init__.py) \
         reverses arguments on diff before delegating. Same shape as \
         api_repack but on the Python side.";
      violates = [ C7; C3 ];
      perturbs =
        [ "python_cext/tiny_cext/__init__.py";
          "python_ctypes/tiny_ctypes/__init__.py" ];
      perturbation = ml_patch "api_repack_python";
      expected = [
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];
    };
    { name = "api_complete_python";
      description =
        "Python user-facing layer drops the sum function. Probes raise \
         AttributeError at runtime; c2 cmp_api_completeness catches it \
         statically via watchlist {sum, diff, offset}.";
      violates = [ C2 ];
      perturbs =
        [ "python_cext/tiny_cext/__init__.py";
          "python_ctypes/tiny_ctypes/__init__.py" ];
      perturbation = ml_patch "api_complete_python";
      expected = [
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Fail;
        "cmp_api_complete_ctypes", Fail;
      ];
    };
    { name = "app_over_binding_ocaml";
      description =
        "Positive-coverage: an app linking directly against the Tiny \
         OCaml binding builds and runs; transitive dependency on \
         libtiny.so resolves. No perturbation.";
      violates = [];
      perturbs = [];
      perturbation = None;
      expected = [
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];
    };
    { name = "app_over_helper_ocaml";
      description =
        "Positive-coverage: longest-interesting chain — app -> \
         tiny_helper -> Tiny binding -> libtiny.so. Confirms \
         intra-binding repacking composes across a downstream library \
         layer. No perturbation.";
      violates = [];
      perturbs = [];
      perturbation = None;
      expected = [
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];
    };
    { name = "api_repack_stub_orphan";
      description =
        "Stub-side orphan: Tiny_raw.mli adds external alias_sum with a \
         matching caml_tiny_alias_sum C wrapper, but Tiny.mli doesn't \
         surface it. Binding compiles + links + probes pass; c7 \
         cmp_api_repack catches via bo1.externals \\ bo4.vals.";
      violates = [ C7 ];
      perturbs =
        [ "ocaml/tiny_raw.ml"; "ocaml/tiny_raw.mli"; "ocaml/tiny_stubs.c" ];
      perturbation = ml_patch "api_repack_stub_orphan";
      expected = [
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];
    };
  ]

(** Print scenario names, one per line — Phase B parity target for
    [python3 canary/examples/tiny/scenarios/scenarios.py list]. *)
let print_list () =
  List.iter scenarios ~f:(fun s -> Stdlib.print_endline s.name)

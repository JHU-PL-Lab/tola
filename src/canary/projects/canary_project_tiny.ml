(** Project: tiny — the in-tree foundational witness for surface theory.

    {b Phase 4 milestone (2026-05-28).} This module exists so that
    [canary action tiny] runs every action graph step on tiny's
    minimal C library + OCaml binding using the production canary
    pipeline. It is the integration check that closes the loop
    between [doc/canary/research/surface_theory.md], [tiny.md], and
    the canary code.

    Unlike z3/llvm/sqlite (which fetch from package managers or
    upstream source repos), tiny lives in the repository at
    [canary/examples/tiny/] and builds entirely from in-tree source:

    - {i n4 lib_native.so} produced by [cmake -S c -B c/build]
    - {i bo3..bo7 compiled_binding_ocaml.*} produced by [dune build]
      with [LIBRARY_PATH] pointed at the cmake output dir
    - {i bo6/bo7/bo4} surfaces extracted by the standard inspector
      scripts ([inspect_native.py], [inspect_binding.py],
      [inspect_ocaml.py])

    Python bindings (cext, ctypes) are intentionally not driven from
    canary today — the tiny harness ([scenarios/scenarios.py],
    [_harness/run_cached.py]) covers them already, and adding them to
    the canary spec would require additional uv / pip command handling
    that isn't load-bearing for the Phase 4 alignment check.

    Aligned vocabulary: this spec uses canonical names in commentary
    ({i lib_native}, {i compiled_binding_ocaml.cmxa}, etc.) and ties
    each command to the artifact it produces / consumes via the same
    aliases the tiny harness uses. *)

open Base
open Canary_basic
open Canary

(** Tiny lives in-tree. All shell commands here run from the tola
    repository root (canary's runner inherits the invoker's cwd, which
    for [dune exec] is the project root). Relative paths anchor to
    [canary/examples/tiny/] explicitly. *)
let tiny_root = "canary/examples/tiny"

(** Absolute path to tiny's cmake build directory (where {i n4
    lib_native.so} ends up). Used for [LIBRARY_PATH] / [LD_LIBRARY_PATH]
    so the OCaml binding's cstubs link against the right libtiny. *)
let tiny_lib_dir = Printf.sprintf "$PWD/%s/c/build" tiny_root

(** Module-level watchlist for tiny's OCaml user-facing surface (bo4
    [user_binding_ocaml.mli]). These three vals are what every probe in
    the tiny harness exercises. *)
let tiny_ocaml_module_watchlist = [ "Tiny" ]
let tiny_ocaml_val_watchlist = [ "sum"; "diff"; "offset" ]

let script_spec : Canary_action.script_spec =
  {
    Canary_action.empty_script_spec with

    (* No fetch_source: tiny is in-tree. *)
    (* No api_source: tiny doesn't go through the api_source flow today;
       the tiny harness handles inspector chaining directly. *)

    (* Configure: cmake -S c -B c/build. The trailing marker-write satisfies
       canary's default check_post (looks for conf.ok in output_dir). *)
    configure = Some (fun ~output_dir ~variant_key ->
      let conf_ok = Canary_step_key.variant_file ~variant_key "conf.ok" in
      Printf.sprintf
        "cmake -S %s/c -B %s/c/build && echo 'ok' > %s/%s"
        tiny_root tiny_root output_dir conf_ok);

    (* Build_lib produces lib_native.so (n4) at c/build/libtiny.so.1. *)
    build_lib = Some (fun ~output_dir ~variant_key ->
      let build_ok = Canary_step_key.variant_file ~variant_key "build.ok" in
      Printf.sprintf
        "cmake --build %s/c/build && echo 'ok' > %s/%s"
        tiny_root output_dir build_ok);

    (* Build_binding OCaml: dune build under canary/examples/tiny/ocaml/.
       Produces:
       - compiled_binding_ocaml.cmxa (bo6)
       - compiled_binding_ocaml.stub-a (bo7) = libtiny_stubs.a
       - examples/probe_baseline.exe (the s6 carrier)
       LIBRARY_PATH lets the cstubs link find libtiny; LD_RUN_PATH bakes
       the rpath into the binding so probe runs without LD_LIBRARY_PATH. *)
    build_binding = [
      (Canary_artifact_api.OCaml,
       fun ~output_dir ~variant_key ->
         let build_ok = Canary_step_key.variant_file ~variant_key "build.ok" in
         (* Invoke dune from the tola root (where dune-project lives) with
            the example tree as an explicit target. Avoids "path cannot
            escape the context root" that bites when cd'ing into the
            example subdir. *)
         Printf.sprintf
           "LIBRARY_PATH=%s LD_RUN_PATH=%s dune build %s/ocaml && \
            echo 'ok' > %s/%s"
           tiny_lib_dir tiny_lib_dir tiny_root output_dir build_ok);
    ];

    (* Probe_binding OCaml: run the probe_baseline.exe. The binary was
       built with rpath baked in (LD_RUN_PATH above), so LD_LIBRARY_PATH
       is a safety net rather than strictly required. probe.log marker
       captures stdout (default check_post). *)
    probe_binding = [
      (Canary_artifact_api.OCaml,
       Canary_store.Build_tree,
       fun ~output_dir ~variant_key ->
         let probe_log = Canary_step_key.variant_file ~variant_key "probe.log" in
         Printf.sprintf
           "LD_LIBRARY_PATH=%s _build/default/%s/ocaml/examples/probe_baseline.exe \
            > %s/%s 2>&1"
           tiny_lib_dir tiny_root output_dir probe_log);
    ];

    (* Explicit inspect override per probe — keep tiny harness's flat
       inspector chain. The artifacts being inspected here are:
       - Probe (Binding OCaml) → bo4 user_binding_ocaml.mli (the watchlist
         driver for c2 cmp_api_completeness). *)
    inspect = (fun rule _loc -> match rule with
      | Probe (Binding Canary_artifact_api.OCaml) ->
          Some (fun ~output_dir ~variant_key ->
            Canary_artifact_lang.inspect_cmd
              ~archive:(Printf.sprintf "_build/default/%s/ocaml/tiny.cmxa" tiny_root)
              ~watchlist:tiny_ocaml_module_watchlist
              ~output_dir ~variant_key ())
      | _ -> None);

    (* Diagram labels: bind the canary kinds to the canonical names tiny uses. *)
    artifact_name = (function
      | Lib -> Some "lib_native.so (libtiny.so.1)"
      | Binding Canary_artifact_api.OCaml ->
          Some "compiled_binding_ocaml (tiny.cmxa + libtiny_stubs.a)"
      | App -> Some "probe_baseline.exe"
      | _ -> None);

    expectation = (fun rule _loc -> match rule with
      | Probe (Binding Canary_artifact_api.OCaml) -> Expect_success
      | _ -> Expect_success);

    (* Baseline tiny: every probe must produce the values the
       probe_baseline.{ml,py} reference set asserts. The tiny harness
       captures broken variants under scenarios/_cache/<scenario>/; this
       canary path runs only the healthy baseline. *)
  }

(* Suppress unused-binding warnings on the val-level watchlist; reserved
   for a future inspect that targets bo4 via inspect_binding.py --kind mli. *)
let _ = tiny_ocaml_val_watchlist

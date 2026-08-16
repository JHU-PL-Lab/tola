(** Binding realization — binding_decl × ctx → command builders
    (M2 step 4, [doc/canary/design/mechanism_payload.md] step 3,
    2026-08-15).

    A project declares its binding as ONE typed record
    ([Canary_binding_decl.binding_decl]); this module derives the
    absorbable [Canary_step_builder.runner_spec] fields from it —
    the build/probe command builders, the probe_lib template, the
    user-facing pkg name. Two stages: the [build_recipe] datatype +
    [recipe_of_decl] mechanism model turn facts into a build recipe
    (Raw = the project's own command), then the recipe × ctx becomes
    command strings. Mechanism-general FACTS (coupling, native
    prefix, surface_path) become commands; store locations + the
    probe choice stay ctx (the decl cannot know where a store lives
    or which example a project probes — that is the analysis side of
    mechanism_payload.md).

    No behavior change: for tiny the emitted strings are byte-equal
    to the former hand-written literals (pinned by
    [tiny_binding_realization_pin] in canary_projects_test.ml). *)

open Base

(** Store/analysis facts the decl cannot know. [lib_dir] is the
    ANCHORED native lib dir (the caller $PWD-prefixes relative
    workspaces); [lib_path] is the lib FILE (probe_lib's nm target). *)
type ctx = {
  lib_dir      : string;  (** anchored, e.g. "$PWD/<ws>/c/build" *)
  lib_path     : string;  (** e.g. "<ws>/c/build/libtiny.so.1" *)
  source_root  : string;  (** dune / probe source root *)
  binding_root : string;  (** the binding product store root *)
  probe_exe    : string;  (** OCaml probe exe, source-root-relative *)
  probe_script : string;  (** Python probe script, binding-root-relative *)
}

(* Compiled_ext product glob: <binding_root>/<pkg>/<product>, where
   <pkg> is the decl source's directory minus its leading store
   component ("python_cext/tiny_cext/_native.c" → "tiny_cext"). *)
let cext_product_glob (d : Canary_binding_decl.binding_decl) ~(ctx : ctx) =
  let source, product =
    match d.facts.coupling with
    | Canary_binding_decl.Compiled_ext ce -> (ce.source, ce.product)
    | Canary_binding_decl.Stub_archive _ | Canary_binding_decl.Dlopen _ ->
        failwith "cext_product_glob: not a Compiled_ext decl"
  in
  let dir_parts =
    match List.rev (String.split ~on:'/' source) with
    | _file :: dir_rev -> List.rev dir_rev
    | [] -> []
  in
  let pkg =
    match dir_parts with
    | _store :: pkg -> String.concat ~sep:"/" pkg
    | [] -> ""
  in
  [%string "%{ctx.binding_root}/%{pkg}/%{product}"]

(* ── the build stage (M2 step 5, 2026-08-15) — the HOW, a separate
   datatype from the declaration: a mechanism-model-derived recipe by
   default, [Raw] where the project's own command builds (external
   projects — their original commands are respected as-is). Project
   knowledge that is not mechanism-determined (tiny's factory cc
   recipe) stays with the factory. *)
type build_recipe =
  | Dune_targets of string list
      (** cstubs: dune-build the user-facing cmxa + the stub archive *)
  | Verify_product
      (** cext: the store provides the product — verify it exists *)
  | Raw
      (** the project's own command — no template (external projects) *)

(** The mechanism model: the decl's facts determine the recipe. *)
let recipe_of_decl (d : Canary_binding_decl.binding_decl) : build_recipe =
  match d.facts.coupling with
  | Canary_binding_decl.Stub_archive sa ->
      (* the user-facing library's cmxa shares the surface module name
         (tiny's convention; a project with a different lib layout
         declares Raw) *)
      let mli = Stdlib.Filename.basename d.facts.surface_path in
      let mod_name =
        Option.value (String.chop_suffix mli ~suffix:".mli") ~default:mli in
      let cmxa =
        Stdlib.Filename.concat
          (Stdlib.Filename.dirname d.facts.surface_path)
          (mod_name ^ ".cmxa") in
      Dune_targets [ cmxa; sa.archive ]
  | Canary_binding_decl.Compiled_ext _ -> Verify_product
  | Canary_binding_decl.Dlopen _ -> Raw

(** The build_binding command for the decl's recipe, or [None] for
    [Raw] (the project declares its own command) and for couplings with
    no compile stage (Dlopen — probe-only chains). *)
let build_binding_of (d : Canary_binding_decl.binding_decl) ~(ctx : ctx)
  : (output_dir:string -> variant_key:string -> string) option =
  match recipe_of_decl d with
  | Dune_targets targets ->
      Some (fun ~output_dir ~variant_key ->
        let build_log = Canary_basic.variant_file ~variant_key "build.log" in
        let dune_cmd =
          Canary_build_cmd.dune_build_cmd
            ~env_extra:
              [ [%string "LIBRARY_PATH=%{ctx.lib_dir}"];
                [%string "LD_RUN_PATH=%{ctx.lib_dir}"] ]
            ~root:ctx.source_root
            ~target:(String.concat ~sep:" " targets) () in
        Printf.sprintf "(%s) > %s/%s 2>&1" dune_cmd output_dir build_log
        |> Canary_build_cmd.with_marker
             ~marker:"build.ok" ~output_dir ~variant_key)
  | Verify_product ->
      (* Verify the store-provided product exists (tiny's cext is
         pre-built by the factory; the factory-side cc recipe is
         project knowledge). *)
      Some (fun ~output_dir ~variant_key ->
        Printf.sprintf "ls %s > /dev/null" (cext_product_glob d ~ctx)
        |> Canary_build_cmd.with_marker
             ~marker:"build.ok" ~output_dir ~variant_key)
  | Raw -> None

(** The probe_binding command for the decl's mechanism, or [None] when
    the base spec does not wire one (Dlopen today — the Cext entry
    serves both Python artifacts through the lang-keyed lookup). *)
let probe_binding_of (d : Canary_binding_decl.binding_decl) ~(ctx : ctx)
  : (output_dir:string -> variant_key:string -> string) option =
  match d.facts.coupling with
  | Canary_binding_decl.Stub_archive _ ->
      Some (fun ~output_dir ~variant_key ->
        let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
        Printf.sprintf
          "(LIBRARY_PATH=%s LD_RUN_PATH=%s dune build --root %s %s \
           && LD_LIBRARY_PATH=%s %s/_build/default/%s) > %s/%s 2>&1"
          ctx.lib_dir ctx.lib_dir ctx.source_root ctx.probe_exe
          ctx.lib_dir ctx.source_root ctx.probe_exe output_dir probe_log)
  | Canary_binding_decl.Compiled_ext _ ->
      Some (fun ~output_dir ~variant_key ->
        let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
        Printf.sprintf
          "LD_LIBRARY_PATH=%s PYTHONPATH=%s python3 \
           %s/%s > %s/%s 2>&1"
          ctx.lib_dir ctx.binding_root ctx.binding_root ctx.probe_script
          output_dir probe_log)
  | Canary_binding_decl.Dlopen _ -> None

(** probe_lib: nm the lib for the declared symbol prefix (verbatim —
    tiny's "tiny_" carries its own trailing underscore). *)
let probe_lib_of (f : Canary_binding_decl.native_facts) ~lib_path
  : output_dir:string -> variant_key:string -> string =
  fun ~output_dir ~variant_key ->
    let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
    Printf.sprintf "nm -D %s | grep -E '^[0-9a-f]+ T %s' > %s/%s 2>&1"
      lib_path f.prefix output_dir probe_log

(** The user-facing package name the binding inspects:
    OCaml — the .mli's module name; Python — the surface's package dir. *)
let user_facing_pkg_of (lang : Canary_lang.lang)
    (d : Canary_binding_decl.binding_decl) : string option =
  let path = d.facts.surface_path in
  match lang with
  | Canary_lang.OCaml ->
      let base = Stdlib.Filename.basename path in
      Some (Option.value (String.chop_suffix base ~suffix:".mli") ~default:base)
  | Canary_lang.Python ->
      Some (Stdlib.Filename.basename (Stdlib.Filename.dirname path))
  | _ -> None

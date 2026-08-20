(* Project: cairo — Pattern A (system libcairo + opam cairo2 binding).
   4 reverse deps in opam; conf-cairo → cairo2 is the canonical graphics
   Pattern A. Spec is a thin declaration over canary_pattern_a; the real
   shape is in canary_pattern_a.runner_spec.

   First new-from-survey project onboarded on the post-redesign machinery
   (store_config / Derived fetch_lib via pattern_a). Positive-only
   (Level A): the binding compiles + a trivial draw round-trips.

   freetype is a cairo depopt (glyph rendering); skipped — the core
   surface/context/paint path here doesn't need it. *)

(* The C API declaration (2026-08-13, spec-check fulfillment): cairo's
   public headers live at src/*.h in the repo; the canonical remote is
   gitlab.freedesktop.org (MRs are the report workflow there). *)
let cairo_native_watchlist = [
  "cairo_create";
  "cairo_destroy";
  "cairo_paint";
  "cairo_move_to";
  "cairo_line_to";
  "cairo_stroke";
  "cairo_image_surface_create";
  "cairo_surface_destroy";
]

let cairo_ocaml_watchlist = [ "Cairo" ]

let cairo_api_source : Canary_artifact.t =
  { Canary_artifact.native_api =
      { kind = Canary_artifact.C;
        components = [ Canary_artifact.Headers; Canary_artifact.Runtime_lib ];
        headers =
          Some
            { Canary_artifact.dir = "src";
              files = [ "cairo.h"; "cairo-ft.h"; "cairo-pdf.h"; "cairo-ps.h";
                        "cairo-svg.h" ] };
        symbol_prefixes = [ "cairo_" ];
        stable_symbols = cairo_native_watchlist;
        versioned_symbols = [];
        soname = None;
        c_runtime = None;
        cxx_abi = None };
    binding_apis =
      [ { Canary_artifact.lang = Canary_lang.OCaml;
          source_dir = None;
          module_watchlist = cairo_ocaml_watchlist;
          type_watchlist = [] } ] }

let cairo_source_stable : Canary_artifact_source.source_repo =
  { Canary_artifact_source.name = "cairo";
    remote = Some (Git
        "https://gitlab.freedesktop.org/cairo/cairo.git");
    locals = [];
    version = Canary_basic.{ channel = Canary_basic.Stable; id = "1.18.0" };
    ref_ = "1.18.0";
    official = true;
    build_sys_deps = [];
    api_source = Some cairo_api_source;
    label = None;
    (* the repo builds the C lib; cairo2 (opam) is off-tree *)
    artifacts = [ Canary_artifact.a_lib ] }

let decl : Canary_opam_binding.t = {
  name = "cairo";
  opam_pkg = "cairo2";
  ocamlfind_pkg = "cairo2";
  system_pkg_linux = "libcairo2-dev";
  system_pkg_macos = "cairo";
  example_file = "canary/examples/cairo/cairo_example.ml";
  example_target = "cairo_example";
  binding_lib = "cairo2";
  lib = {
    linux_glob = "/usr/lib/x86_64-linux-gnu/libcairo.so* /usr/lib*/libcairo.so*";
    brew_pkg = "cairo";
    brew_dylib = "libcairo.dylib";
  };
  native_probe_prefix = "cairo_";
  native_inspect_prefixes = [ "cairo_" ];
  (* Core cairo entry points: surface + context lifecycle and basic
     drawing. Present since cairo 1.0 (2005); removing one would be a
     major upstream break — exactly the bellwether the watchlist is for. *)
  native_watchlist = cairo_native_watchlist;
  (* cairo2 ships a single top-level compilation unit [Cairo]. Drift here
     would be a major version bump. *)
  ocaml_module_watchlist = cairo_ocaml_watchlist;
  sources = [ cairo_source_stable ];
  (* the C LIB's own repo (cairo/cairo.git) — the default *)
  source_of_binding = None;
  binding_mechanism = Canary_mechanism.Cstubs;
  (* measured: opam `cairo2` depends on `conf-cairo`, no version
     constraint — same free shape as zarith *)
  pm_gate = Canary_binding_decl.Free_with_conf "conf-cairo";
  (* the lib's LATEST point (landing.md §3): cairographics.org publishes
     source .tar.xz only, so conda-forge supplies the newest prebuilt —
     1.18.4, which is also upstream's newest, against apt's 1.18.0.
     NOTE the earlier mistake this comment exists to prevent: an older
     cairo (1.14.12) was proposed to manufacture a version gap. The pair
     asks whether today's binding works with TOMORROW's lib; an older lib
     answers a question nobody has. *)
  prebuilt_latest =
    Some
      { Canary_prebuilt.project = "cairo";
        tag = "cairo-1.18.4";
        version = "1.18.4";
        url =
          "https://conda.anaconda.org/conda-forge/linux-64/cairo-1.18.4-h3394656_0.conda";
        lib_glob = "lib/libcairo.so*";
        note =
          "conda-forge 1.18.4 = upstream's newest (2025-03-08); apt ships \
           1.18.0. cairographics.org publishes source only." };
  wrapper = None;
}

let runner_spec = Canary_opam_binding.runner_spec decl

(* Registry entry: Pattern A's typed artifact table + the template's
   runner_spec (single scenario: source + lib + binding Fetched@Stable). *)
let cairo_run : Canary_project_run.project_run = Canary_opam_binding.run decl

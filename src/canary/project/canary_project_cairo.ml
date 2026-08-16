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

let decl : Canary_pattern_a.t = {
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
  source = Some cairo_source_stable;
  binding_mechanism = Canary_mechanism.Cstubs;
}

let runner_spec = Canary_pattern_a.runner_spec decl

(* Registry entry: Pattern A's typed artifact table + the template's
   runner_spec (single scenario: source + lib + binding Fetched@Stable). *)
let cairo_run : Canary_project_run.project_run = Canary_pattern_a.run decl

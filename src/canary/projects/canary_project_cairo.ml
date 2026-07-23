(* Project: cairo — Pattern A (system libcairo + opam cairo2 binding).
   4 reverse deps in opam; conf-cairo → cairo2 is the canonical graphics
   Pattern A. Spec is a thin declaration over canary_pattern_a; the real
   shape is in canary_pattern_a.runner_spec.

   First new-from-survey project onboarded on the post-redesign machinery
   (store_config / Derived fetch_lib via pattern_a). Positive-only
   (Level A): the binding compiles + a trivial draw round-trips.

   freetype is a cairo depopt (glyph rendering); skipped — the core
   surface/context/paint path here doesn't need it. *)

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
  native_watchlist = [
    "cairo_create";
    "cairo_destroy";
    "cairo_paint";
    "cairo_move_to";
    "cairo_line_to";
    "cairo_stroke";
    "cairo_image_surface_create";
    "cairo_surface_destroy";
  ];
  (* cairo2 ships a single top-level compilation unit [Cairo]. Drift here
     would be a major version bump. *)
  ocaml_module_watchlist = [ "Cairo" ];
}

let runner_spec = Canary_pattern_a.runner_spec decl

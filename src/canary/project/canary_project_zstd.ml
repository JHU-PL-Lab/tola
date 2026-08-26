(* Project: zstd — Pattern A (system libzstd + the opam `zstd` binding).

   WHY, AND WHY SECOND (2026-08-20). The conf-* survey ranked it #2
   behind zlib (surveys/conf_packages.md §G5): the same declaration-only
   shape, a small closure, and it is one of `bytesrw`'s five optional
   backends — so landing it standalone de-risks that later arc. It landed
   the day `libzstd-dev` became installable (before that `conf-zstd`
   could not run its check at all — issues.md).

   WHAT IT ADDS OVER ZLIB. Three things, each a first:

   1. A GATE THAT ACTUALLY BOUNDS THE LIB. `conf-zstd.1.3.8`'s build is
      `pkg-config --atleast-version=1.3.8 libzstd` — a version predicate,
      not a presence check. It is one of only 13 conf packages in the
      repository that enforce a library version (§G1a), and the FIRST one
      canary declares with [tracks_lib = true]. Note where the bound comes
      from: the opam `zstd` package depends on a bare `"conf-zstd"` with
      no constraint of its own, so reading only
      `opam show --field=depends` would call this Free_with_conf. The
      floor is the conf package's, and it is real.

   2. TWO INDEPENDENT WORLD WITNESSES. The binding exposes
      [Zstd.version ()], which is a ctypes call to `ZSTD_versionNumber()`
      in the LOADED library — so the probe reports the answering library's
      own opinion of its version, alongside the loader's opinion of which
      file it mapped (/proc/self/maps). zlib's probe has only the second,
      because camlzip exposes no `zlibVersion()`. Measured:

        fetched world:  zstd version: 1.5.5
                        zstd resolved: /usr/lib/.../libzstd.so.1.5.5
        vendored world: zstd version: 1.5.7
                        zstd resolved: <contrib>/zstd-all/prebuilt/
                                       zstd-1.5.7/lib/libzstd.so.1.5.7

   3. NO ELF SYMBOL VERSIONING — the contrast that makes zlib's
      interesting. zstd carries zero version nodes on either side
      (`readelf -V`), so the soname is its ONLY load-time gate and it
      matches (libzstd.so.1 both sides). zlib, at the same
      "same soname, purely additive" description, adds ZLIB_1.3.1.2 /
      ZLIB_1.3.2 nodes and can therefore refuse a consumer at load time.
      Same-soname is not one property; it is the absence of a second gate
      that may or may not exist.

   A MEASUREMENT TRAP THIS PROJECT EXPOSES. The two builds export 185 and
   598 symbols respectively — a 3× difference for the same library line,
   with NOTHING removed in either direction. Debian hides zstd's internals
   (`ZSTD_XXH*`, `ZSTD_buildCTable`, `FSE_*`, `COVER_*`); conda-forge's
   build exports them. So a raw exported-symbol COUNT compares packaging
   policy, not API, and is meaningless across providers. The named
   watchlist is the check that means something — which is what it is for. *)

let zstd_native_watchlist =
  [ (* the simple one-shot API the binding calls, plus the context
       lifecycle and the error protocol. Stable since zstd 1.0 (2016);
       all present in both builds (verified across apt 1.5.5 and
       conda-forge 1.5.7 before landing). *)
    "ZSTD_compress";
    "ZSTD_decompress";
    "ZSTD_compressBound";
    "ZSTD_getFrameContentSize";
    "ZSTD_isError";
    "ZSTD_getErrorName";
    (* the runtime version accessor — the symbol behind [Zstd.version ()],
       and therefore behind this project's second world witness *)
    "ZSTD_versionNumber" ]

(* The opam `zstd` package installs findlib `zstd` (zstd.cmxa) plus
   `zstd.stubs`. The user-facing surface is the single module Zstd. *)
let zstd_ocaml_watchlist = [ "Zstd" ]

let zstd_api_source : Canary_artifact.t =
  { Canary_artifact.native_api =
      { kind = Canary_artifact.C;
        components = [ Canary_artifact.Headers; Canary_artifact.Runtime_lib ];
        headers =
          Some
            { Canary_artifact.dir = "include";
              files = [ "zstd.h"; "zstd_errors.h" ] };
        symbol_prefixes = [ "ZSTD_" ];
        stable_symbols = zstd_native_watchlist;
        versioned_symbols = [];
        soname = Some "libzstd.so.1";
        c_runtime = None;
        cxx_abi = None };
    binding_apis =
      [ { Canary_artifact.lang = Canary_lang.OCaml;
          source_dir = None;
          module_watchlist = zstd_ocaml_watchlist;
          type_watchlist = [] } ] }

(* The C lib's own repo. 1.5.7 is upstream's newest tagged release and is
   also what conda-forge ships, so the source row and the vendored point
   agree on the version — unlike zlib, where conda-forge's 1.3.2 has no
   upstream tag. *)
let zstd_source_stable : Canary_artifact_source.source_repo =
  { Canary_artifact_source.name = "zstd";
    remote = Some (Git "https://github.com/facebook/zstd.git");
    locals = [];
    version = Canary_basic.{ channel = Canary_basic.Stable; id = "1.5.7" };
    ref_ = "v1.5.7";
    official = true;
    build_sys_deps = [];
    api_source = Some zstd_api_source;
    label = None;
    artifacts = [ Canary_artifact.a_lib ] }

let decl : Canary_opam_binding.t =
  { name = "zstd";
    opam_pkg = "zstd";
    (* findlib `zstd` owns the archive directly (zstd.cmxa) — unlike
       camlzip, whose findlib entry is an empty alias over `zip` *)
    ocamlfind_pkg = "zstd";
    system_pkg_linux = "libzstd-dev";
    system_pkg_macos = "zstd";
    example_file = "canary/examples/zstd/zstd_example.ml";
    example_target = "zstd_example";
    binding_lib = "zstd";
    lib =
      { linux_glob =
          "/usr/lib/x86_64-linux-gnu/libzstd.so.1* /usr/lib*/libzstd.so.1*";
        brew_pkg = "zstd";
        brew_dylib = "libzstd.dylib" };
    native_probe_prefix = "ZSTD_";
    native_inspect_prefixes = [ "ZSTD_"; "ZDICT_" ];
    native_watchlist = zstd_native_watchlist;
    ocaml_module_watchlist = zstd_ocaml_watchlist;
    sources = [ zstd_source_stable ];
    (* the C LIB's own repo (facebook/zstd.git) — the default *)
    source_of_binding = None;
    (* the binding uses ctypes STUB GENERATION (findlib zstd.stubs ships a
       compiled stub archive), so the C entry points are resolved at LINK
       time, not dlsym'd — Static_c_abi, hence [Cstubs] rather than the
       [Ctypes] that libffi's genuinely dynamic ctypes-foreign gets. *)
    binding_mechanism = Canary_mechanism.Cstubs;
    (* MEASURED, all three halves (landing.md §3b) — and the second one is
       why this project is not Free_with_conf:
       1. `opam show zstd --field=depends` → a bare "conf-zstd", NO
          version constraint from the binding;
       2. conf-zstd.1.3.8's build IS a version predicate:
          `pkg-config --atleast-version=1.3.8 libzstd`. The floor belongs
          to the conf package, and it reaches the library — so
          [tracks_lib = true] and the freedom is [Within_bound ">= 1.3.8"],
          not [Any_version]. Both of our points (apt 1.5.5, conda-forge
          1.5.7) clear it, so the gate does not bite here; declaring it
          Free would have been convenient and false.
       3. the binding's own build runs no version test (no extra-source
          compatibility program, unlike mlmpfr). *)
    pm_gate =
      Canary_binding_decl.Bounded_with_conf
        { conf = "conf-zstd";
          lower = Some "1.3.8";
          upper = None;
          tracks_lib = true };
    (* THE LATEST POINT, by the sourcing rule (landing.md §3): facebook/zstd
       publishes source tarballs and Windows binaries only — no Linux
       artifact — so step 2 falls through to conda-forge, whose newest
       linux-64 build is 1.5.7, which is ALSO upstream's newest tag. Same
       soname (libzstd.so.1) as apt's 1.5.5 and a two-entry closure
       (NEEDED: libpthread, libc), so the vendored world is a pure
       LD_LIBRARY_PATH repoint.

       Package note: unlike zlib, conda-forge does NOT split zstd — the
       one `zstd` package carries the runtime object, the headers and the
       .pc file together, so this prebuilt could also serve a world that
       COMPILES against 1.5.7. *)
    prebuilt_latest =
      Some
        { Canary_prebuilt.project = "zstd";
          tag = "zstd-1.5.7";
          version = "1.5.7";
          linux =
            { url =
                "https://conda.anaconda.org/conda-forge/linux-64/zstd-1.5.7-hb78ec9c_7.conda";
              lib_glob = "lib/libzstd.so.1*" };
          (* same version and build number (_7) as linux-64 *)
          macos =
            Some
              { url =
                  "https://conda.anaconda.org/conda-forge/osx-arm64/zstd-1.5.7-hf451053_7.conda";
                lib_glob = "lib/libzstd.1*.dylib" };
          note =
            "conda-forge 1.5.7 = upstream's newest tag (facebook/zstd \
             publishes no Linux binary); apt ships 1.5.5. Same soname \
             libzstd.so.1, no ELF symbol versioning on either side, \
             closure = libpthread + libc. The two builds export 185 vs \
             598 symbols with nothing REMOVED — Debian hides zstd's \
             internals and conda-forge does not, which is why a raw \
             symbol count is not comparable across packagers." };
    (* the probe prints BOTH witnesses: `zstd version: 1.5.7` (a runtime
       ZSTD_versionNumber() call) and `zstd resolved: <path>` (the loader's
       mapping). The vendored world asserts the path. *)
    probe_names_lib = true;
    wrapper = None }

let runner_spec = Canary_opam_binding.runner_spec decl

(* Registry entry: two scenarios — the lib's Fetched@Stable (apt 1.5.5)
   and Vendored@Dev (conda-forge 1.5.7) points against the opam binding. *)
let zstd_run : Canary_project_run.project_run = Canary_opam_binding.run decl

(* Project: zlib — Pattern A (system zlib + opam camlzip binding).

   WHY THIS PROJECT, AND WHY FIRST (2026-08-20). The conf-* survey's
   sampling (surveys/conf_packages.md §G5) ranked it #1 of the unlanded
   candidates on three counts measured, not guessed:

   - HIGHEST UNCOVERED REVDEPS. conf-zlib has 56 opam reverse
     dependencies — the largest of any C library we do not already cover
     that has a real binding (camlzip, cryptokit, and the `zlib` package
     all bind it).
   - A FREE GATE. camlzip's whole dependency list is
     `ocaml >= 4.13.0`, `ocamlfind {build}`, `conf-zlib` — and conf-zlib's
     entire build is `pkg-config zlib`, a bare presence check with no
     version predicate. So it is [Free_with_conf] in both the declared and
     the effective sense (§G1a): nothing constrains which zlib we install.
     Contrast conf-zstd, which looks identical from the metadata and runs
     `pkg-config --atleast-version=1.3.8 libzstd`.
   - A POINT-AT-IT PAIR. apt ships libz 1.3, conda-forge ships 1.3.2, and
     both carry SONAME [libz.so.1]. Same soname means the consumer needs
     no rebuild to face the other version — [LD_LIBRARY_PATH] suffices, so
     the 2×2's lib axis is a declaration rather than a build.

   The closure is the smallest we have measured: [readelf -d] on both
   libraries lists exactly one NEEDED entry, [libc.so.6]. Nothing here
   depends on the system happening to satisfy a thirteen-entry graph the
   way cairo's vendored world does.

   THE WORLD IS ASSERTED, NOT ASSUMED. zlib exposes no version through
   camlzip's OCaml surface, so there is no version string for the vendored
   world to grep. The probe instead reads /proc/self/maps and prints the
   library file the loader actually mapped, and the vendored probe asserts
   that path is inside the prebuilt's libdir ([probe_names_lib]). That is
   stronger than a version: it names the answering artifact. Measured
   before landing —

     system world:   zlib resolved: /usr/lib/x86_64-linux-gnu/libz.so.1.3
     vendored world: zlib resolved: <contrib>/zlib-all/prebuilt/
                                    zlib-1.3.2/lib/libz.so.1.3.2

   which is the cairo lesson applied up front: two zlib versions export
   near-identical surfaces, so a silent fallback to the system copy would
   pass for the wrong reason and look exactly like success. *)

let zlib_native_watchlist =
  [ (* the deflate/inflate core — present since zlib 1.0 (1995). These are
       the entry points camlzip's C stubs actually call; removing one
       would be a break nothing in the ecosystem would survive, which is
       what makes them the bellwether. *)
    "deflateInit_";
    "deflate";
    "deflateEnd";
    "inflateInit_";
    "inflate";
    "inflateEnd";
    (* the version accessor: the only symbol that reports WHICH zlib
       answered, and the reason a native-side identity check is possible
       even though the OCaml surface hides it *)
    "zlibVersion" ]

(* camlzip installs findlib package `zip` (with `camlzip` as an alias that
   simply requires it). Modules: Zip (archives), Gzip (files), Zlib (the
   raw deflate/inflate streams the probe uses). *)
let zlib_ocaml_watchlist = [ "Zlib"; "Gzip"; "Zip" ]

let zlib_api_source : Canary_artifact.t =
  { Canary_artifact.native_api =
      { kind = Canary_artifact.C;
        components = [ Canary_artifact.Headers; Canary_artifact.Runtime_lib ];
        headers = Some { Canary_artifact.dir = "include";
                         files = [ "zlib.h"; "zconf.h" ] };
        (* zlib has no single prefix: deflate*/inflate*/gz*/crc32/adler32
           are all public. The two stream families are the ones a binding
           calls, and they are what the count probe ranges over. *)
        symbol_prefixes = [ "deflate"; "inflate" ];
        stable_symbols = zlib_native_watchlist;
        versioned_symbols = [];
        soname = Some "libz.so.1";
        c_runtime = None;
        cxx_abi = None };
    binding_apis =
      [ { Canary_artifact.lang = Canary_lang.OCaml;
          source_dir = None;
          module_watchlist = zlib_ocaml_watchlist;
          type_watchlist = [] } ] }

(* The C lib's own repo. zlib's upstream is madler/zlib; 1.3.1 is the
   newest tagged release (1.3.2 exists as a conda-forge BUILD of the same
   line — see the prebuilt note). Declared for the source row's identity;
   the lib axis is prebuilt-only per prebuilt-shadows-source. *)
let zlib_source_stable : Canary_artifact_source.source_repo =
  { Canary_artifact_source.name = "zlib";
    remote = Some (Git "https://github.com/madler/zlib.git");
    locals = [];
    version = Canary_basic.{ channel = Canary_basic.Stable; id = "1.3.1" };
    ref_ = "v1.3.1";
    official = true;
    build_sys_deps = [];
    api_source = Some zlib_api_source;
    label = None;
    artifacts = [ Canary_artifact.a_lib ] }

let decl : Canary_opam_binding.t =
  { name = "zlib";
    opam_pkg = "camlzip";
    (* THE ARCHIVE LIVES UNDER `zip`, NOT `camlzip`. The opam package
       camlzip installs TWO findlib packages: `zip` (zip.cmxa + the
       modules) and `camlzip`, whose META is the single line
       `requires="zip"` — an alias directory holding no archive at all.
       Declaring `camlzip` here made the module inspector read that empty
       directory and report `watchlist: 0 present, MISSING Zlib,Gzip,Zip`
       on a run that was otherwise green (2026-08-20, caught by the
       watchlist on the first zlib run — the check earning its keep).
       [ocamlfind_pkg] is what gets INSPECTED, so it must name the package
       that actually owns the archive; [binding_lib] is what gets LINKED,
       where the alias resolves fine either way. *)
    ocamlfind_pkg = "zip";
    system_pkg_linux = "zlib1g-dev";
    system_pkg_macos = "zlib";
    example_file = "canary/examples/zlib/zlib_example.ml";
    example_target = "zlib_example";
    binding_lib = "camlzip";
    lib =
      { linux_glob = "/usr/lib/x86_64-linux-gnu/libz.so.1* /usr/lib*/libz.so.1*";
        brew_pkg = "zlib";
        brew_dylib = "libz.dylib" };
    (* deflate* is the family the binding calls most; a single prefix keeps
       the count probe's number comparable across versions *)
    native_probe_prefix = "deflate";
    native_inspect_prefixes = [ "deflate"; "inflate"; "gz"; "crc32"; "adler32" ];
    native_watchlist = zlib_native_watchlist;
    ocaml_module_watchlist = zlib_ocaml_watchlist;
    sources = [ zlib_source_stable ];
    (* the C LIB's own repo (madler/zlib.git) — the default *)
    source_of_binding = None;
    (* camlzip links C stubs (libcamlzip.a) against libz at build time and
       calls them through the OCaml runtime — Static_c_abi *)
    binding_mechanism = Canary_mechanism.Cstubs;
    (* MEASURED, both halves (landing.md §3b):
       1. `opam show camlzip --field=depends` → a bare "conf-zlib", no
          version constraint;
       2. conf-zlib.1's build is `pkg-config zlib` — a presence check with
          no version predicate, so the conf imposes no floor either
          (unlike conf-zstd's --atleast-version=1.3.8).
       3. camlzip's own build runs no version test (no extra-source
          compatibility program, unlike mlmpfr).
       All three free ⇒ Free_with_conf, and the lib axis is limited only
       by what we can obtain. *)
    pm_gate = Canary_binding_decl.Free_with_conf "conf-zlib";
    (* THE LATEST POINT, by the sourcing rule (landing.md §3): zlib.net and
       madler/zlib publish source only — no Linux binary — so step 2 falls
       through to conda-forge. Its newest linux-64 build is 1.3.2, one
       patch ahead of apt's 1.3 and carrying the SAME soname (libz.so.1),
       which is what makes this pair point-at-it rather than rebuild-me.
       Note the package split: conda-forge's `zlib` package ships headers
       and the .so symlink, while the runtime object libz.so.1.3.2 lives
       in `libzlib` — we take `libzlib`, since a Fetched-binding world
       needs the runtime object and gets its headers from apt. *)
    prebuilt_latest =
      Some
        { Canary_prebuilt.project = "zlib";
          tag = "zlib-1.3.2";
          version = "1.3.2";
          url =
            "https://conda.anaconda.org/conda-forge/linux-64/libzlib-1.3.2-h25fd6f3_3.conda";
          lib_glob = "lib/libz.so.1*";
          note =
            "conda-forge libzlib 1.3.2 (upstream publishes source only; \
             apt ships 1.3). Same soname libz.so.1 and a one-entry \
             closure (NEEDED: libc.so.6), so the vendored world is a \
             pure LD_LIBRARY_PATH repoint — the cheapest real lib pair \
             in the registry." };
    (* the probe prints `zlib resolved: <path>` from /proc/self/maps, so
       the vendored world can be asserted rather than assumed *)
    probe_names_lib = true;
    wrapper = None }

let runner_spec = Canary_opam_binding.runner_spec decl

(* Registry entry: Pattern A's typed artifact table + the template's
   runner_spec. Two scenarios — the lib's Fetched@Stable (apt 1.3) and
   Vendored@Dev (conda-forge 1.3.2) points against the opam binding. *)
let zlib_run : Canary_project_run.project_run = Canary_opam_binding.run decl

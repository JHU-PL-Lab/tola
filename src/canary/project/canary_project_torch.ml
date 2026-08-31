(* Project: torch — the opam `torch` binding over libtorch.

   THE PLAN this lands is doc/canary/project/project_pytorch.md. Three of
   its premises were re-measured 2026-08-30 IN THE CANARY SWITCH (the plan
   measured the default switch, and by dry-run only) and two of them
   changed. What follows is what the measurements actually say.

   1. THE BINDING VERSION AXIS HAS ONE POINT, and not for cost reasons.
      On OCaml 5.4.1 — the compiler the canary switch runs — v0.17.0 is
      the ONLY installable torch. The plan expected a v0.16 / v0.17 pair
      and warned the flip might be tier 3 (a Jane Street stack rebuild).
      It is not expensive; it is impossible:

        opam install --dry-run torch.v0.16.0  →  No solution found
          torch = v0.16.0 → core < v0.17 → ocaml < 4.12.0

      The old 0.x series (torch.0.16 / torch.0.17, LaurentMazare's
      packaging) has the same floor. So the axis stops at one point
      because of a compiler bound, the way zarith's lib axis stops at one
      point because apt already ships upstream's newest — a fact about the
      world, recorded in the row's rationale rather than left as an
      apparent omission.

   2. THE LIB AND THE BINDING ARE INDEPENDENT PLACEMENTS. libtorch is
      `depopts` + `{with-test}` in torch's opam file, so `opam install
      torch` installs 70 packages and NOT libtorch. The binding finds the
      library through its own configurator. That is unusually clean for
      canary: the two axes vary without either forcing the other.

   3. THE SOLVER GATE REPRODUCES, HARDER THAN WRITTEN (plan §0b). The
      new gate class — a bound enforced at RESOLUTION time rather than at
      conf-build or binding-build time:

        opam install --dry-run torch libtorch          → picks libtorch 2.1.2
        opam install --dry-run torch libtorch.2.2.1    → No solution found

      On 5.4.1 opam cannot even back off to an older torch, so the answer
      is a flat refusal. The consequence for the enumeration is the
      interesting part and is why the 2.2.1 world must place libtorch
      OUTSIDE opam (see the lib row's rationale).

   THE FINDING, AND WHY THE BINDING ROW HAS TWO PACKAGING POINTS.
   torch.v0.17.0 as published does not build with dune 3.23.1. Its
   src/wrapper/dune declares

     (foreign_stubs (language cxx) (names torch_api))

   while torch_api.cpp line 944 does `#include "torch_api_generated.cpp"`
   — a .cpp included as a header. dune stages the listed .cpp and every
   .h, but not the unlisted .cpp; measured by listing
   _build/default/src/wrapper/, which holds torch_api.h and
   torch_api_generated.h and not torch_api_generated.cpp. The package
   declares (lang dune 3.11) and the staging rule changed under it.

   opam's own post-message blames a missing system libtorch. That is a
   red herring: libtorch 2.1.2 was installed and its -isystem flags are
   in the failing command line. Adding

     (extra_deps torch_api_generated.cpp)

   makes `dune build -p torch` exit 0 with an empty log. That one line is
   the upstream fix, and it is carried verbatim as the patch in
   canary/templates/opam-local-repo/packages/torch/torch.v0.17.0-canary1.

   So the binding row declares TWO points at the SAME upstream version:
   the stock package (a declared build xfail — the finding kept visible as
   a world) and the canary-local patched one (which builds, so the lib
   axis has a consumer that can actually run). They are NOT a channel
   pair: they answer "does this package build here", not "does today's
   binding work with tomorrow's lib". The rationale says so, because
   `spec-check`'s binding-pair counter would otherwise be satisfied for
   the wrong reason. *)

open Base
module SB = Canary_step_builder
module SC = Canary_store_config
module AN = Canary_artifact_native

(* ── identities ── *)

(* The stock package and the canary-local patched one, same upstream
   version. [pin_check_post] compares `opam list --columns=version torch`
   against these, which is why the patched package is a VERSION of `torch`
   rather than a separately-named package: a distinct package name would
   make the world query answer about a package that is not installed. *)
let torch_pin_stock = "v0.17.0"
let torch_pin_patched = "v0.17.0-canary1"

(* opam's libtorch is a NATIVE lib delivered through opam — the first in
   the registry whose stable point is not the system PM.

   THE ID AND THE PACKAGE NAME DIFFER, deliberately. opam spells the
   package `libtorch.2.1.2+linux-x86_64`, and a '+' is born-UNSAFE in a
   scenario name (`pipeline.scenario_names_are_born_safe` rejects it
   alongside ':' — both need escaping in a path or a ':'-separated env
   var). So the identity-bearing id is the dotted version and the real
   package name rides in [install_name], which is what that field is for
   (its own doc cites llvm.19-shared, the same shape). *)
let libtorch_pin = "2.1.2"
let libtorch_opam_pkg = "libtorch.2.1.2+linux-x86_64"

(* torch compiles a 2600-line extern "C" C++ shim (the torch_api and
   torch_api_generated units under src/wrapper) INTO the binding as a static stub archive
   (libtorch_core_stubs.a), then calls at:: / c10:: / torch:: across it.
   The binding↔lib boundary is therefore mangled C++ — see the native
   watchlist — but the OCaml↔C boundary is stub-linked, so the mechanism
   is Cstubs / Static_c_abi. (ctypes-foreign is a dependency, used for the
   generated wrapper's plumbing, not for resolving libtorch at runtime.) *)
let torch_binding_art =
  Canary_artifact.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs

(* ── the API surface ── *)

(* MANGLED, AND MEASURED (plan §0c). libtorch_cpu.so exports 87,877
   symbols, all Itanium-mangled — by far the largest surface in the
   registry (llvm 3801 LLVM-prefixed, z3 705 Z3-prefixed). The plan's §0c
   point holds: c1 is a set
   comparison over strings, and a mangled name is just a longer string, so
   the existing inspector needs no demangler. What it DOES need is
   mangled PREFIXES, because Itanium substitution means the namespace is
   spelled by length: at:: is `_ZN2at`, c10:: is `_ZN3c10`, torch:: is
   `_ZN5torch`. Measured counts on 2.1.2+cpu:

     _ZN2at     17292      _ZN5torch   6197      _ZN3c10   677

   The 36,188 UNMANGLED exports are not a C API — they are the bundled
   BLAS/MKL Fortran symbols (CAXPY, DGEMM, …), which is why a bare
   "count the unmangled ones" probe would report a surface that has
   nothing to do with torch. *)
let torch_native_prefixes = [ "_ZN2at"; "_ZN3c10"; "_ZN5torch" ]

(* The watchlist is deliberately the ARGUMENT-FREE entry points. A mangled
   name encodes the whole signature, so `at::sum(Tensor const&)` changes
   its spelling when an overload is added — a watchlist of those would
   report drift that is not drift. These six take no arguments, so their
   manglings are stable under signature churn, and each is a runtime entry
   point the binding's shim actually reaches. All six verified present in
   2.1.2+cpu before landing. *)
let torch_native_watchlist =
  [ (* at::globalContext() — the ATen runtime context accessor *)
    "_ZN2at13globalContextEv";
    (* at::getCPUAllocator() — the allocator every CPU tensor comes from *)
    "_ZN2at15getCPUAllocatorEv";
    (* the threading API the binding initialises through *)
    "_ZN2at16init_num_threadsEv";
    "_ZN2at15get_num_threadsEv";
    "_ZN2at23get_num_interop_threadsEv";
    "_ZN2at18in_parallel_regionEv" ]

(* MEASURED, and the first guess was wrong (2026-08-30). `Torch` reads
   like the obvious watchlist entry — it is the module the probe writes —
   but the binding inspector reads the package's .mli and reports what is
   INSIDE the wrapper, so a watchlist of ["Torch"] came back
   `missing: ["Torch"]` on a run that was otherwise green. (Confirmed the
   other way too: ocamlobjinfo on torch.cmxa DOES list a `Torch` module,
   so the two inspectors genuinely disagree about the name — the .mli one
   is what the watchlist is checked against.)

   These five are submodules of Torch, all verified present, and chosen
   because the probe reaches the first through Torch.Tensor and the rest
   are the surface a binding user would notice losing. *)
let torch_ocaml_watchlist =
  [ "Tensor"; "Device"; "Scalar"; "Optimizer"; "Cuda" ]

let torch_api_source : Canary_artifact.t =
  { Canary_artifact.native_api =
      { (* the registry's FIRST Cpp_api: z3 and llvm are C++ libraries
           that export a C ABI, so they declare [C]. libtorch has no
           stable C API for what the binding needs, which is why
           ocaml-torch ships its own extern "C" shim — the provider
           surface really is C++ here. *)
        kind = Canary_artifact.Cpp_api;
        components = [ Canary_artifact.Headers; Canary_artifact.Runtime_lib ];
        headers =
          Some { Canary_artifact.dir = "include";
                 files = [ "torch/csrc/api/include/torch/torch.h" ] };
        symbol_prefixes = torch_native_prefixes;
        stable_symbols = torch_native_watchlist;
        versioned_symbols = [];
        (* libtorch_cpu.so carries no SONAME versioning — the shipped
           binaries are unversioned filenames inside a versioned tree,
           which is why the world is asserted by PATH and build-version
           rather than by soname. *)
        soname = None;
        c_runtime = None;
        cxx_abi = None };
    binding_apis =
      [ { Canary_artifact.lang = Canary_lang.OCaml;
          source_dir = None;
          module_watchlist = torch_ocaml_watchlist;
          type_watchlist = [] } ] }

(* ── the binding declaration ── *)

(* MEASURED per landing.md §3b, and the answer strains the vocabulary.

   Step 1, the declared constraint: `opam show torch --field=depends` puts
   libtorch under `{with-test}`, with `depopts: ["libtorch"]` — so nothing
   in `depends` bounds the lib at all.
   Step 2, the conf package: there is none. libtorch is a real opam
   package carrying a binary, not a conf-* probe, so the whole
   [*_with_conf] family is inapplicable.
   Step 3, the binding's own build: torch's `discover.exe` locates
   libtorch through the LIBTORCH variable and does not version-test it.

   The bound lives somewhere none of the three steps looks — the opam
   `conflicts:` field:

     conflicts: [ "libtorch" {< "2.1.0" | >= "2.2.0"} ]

   and it is enforced by the SOLVER, at dependency-resolution time, which
   is a checking point earlier than any gate we had measured (conf build /
   binding build). [Pinned_depext] is the closest constructor and its own
   doc already names torch — but it says "depext", and libtorch is an opam
   package, not a system depext. Declared as [Pinned_depext] so the gate
   is not lost, with the discrepancy recorded here: the constructor should
   grow a solver-conflict sibling, or be renamed, when a second specimen
   turns up. See project_pytorch.md §0b for the gate-class ladder. *)
let torch_binding_decls : Canary_binding_decl.binding_decl list =
  let open Canary_binding_decl in
  [ { mechanism = Canary_mechanism.Cstubs;
      c_api = { functions = torch_native_watchlist; enums = [] };
      native =
        { prefix = "_ZN2at";
          (* libtorch's shipped .so files are unversioned filenames inside
             a versioned tree — no SONAME to compare, which is why the
             world is asserted by build-version and mapped path. *)
          soname = "libtorch_cpu.so";
          headers =
            { dir = "include"; files = [ "torch/csrc/api/include/torch/torch.h" ] } };
      coupling =
        Stub_archive
          { sources = [ "torch_api.cpp"; "torch_api_generated.cpp" ];
            archive = "libtorch_core_stubs.a" };
      surface_path = "torch.mli";
      pm_gate =
        Some (Pinned_depext { depext = "libtorch"; bound = ">= 2.1.0 & < 2.2.0" }) } ]

(* ── the declared source ── *)

(* THE BINDING'S repo, not the lib's — the zarith shape (user 2026-08-19:
   "a ref is used to mark a source who provides a lib or a binding"). The
   lib arrives as an upstream BINARY through opam and is never built here,
   so pytorch/pytorch would be a source nothing in this project reads;
   janestreet/torch is the tree the finding above lives in, and the ref is
   the exact tag both binding points are packaged from. Declared so the
   matrix carries a ref column and `spec-check` can report a remote; the
   fetch is a one-time clone, cached by its marker. *)
let torch_binding_source : Canary_artifact_source.source_repo =
  { Canary_artifact_source.name = "torch";
    remote = Some (Git "https://github.com/janestreet/torch.git");
    locals = [];
    version = Canary_basic.{ channel = Canary_basic.Stable; id = "v0.17.0" };
    ref_ = "v0.17.0";
    official = true;
    build_sys_deps = [];
    api_source = Some torch_api_source;
    label = None;
    artifacts = [ torch_binding_art ] }

(* ── the artifact table ── *)

let torch_rows : Canary_project_spec.artifact_row list =
  [ Canary_project_spec.artifact_row
      ~artifact:(Canary_artifact.a_binding_source Canary_lang.OCaml)
      ~universe:
        [ ( SC.Fetched (SC.Repo torch_binding_source),
            [ Canary_basic.Stable ] ) ]
      ~rationale:
        "the BINDING's repo (janestreet/torch @ v0.17.0), not the lib's: \
         libtorch arrives as an upstream binary through opam and is never \
         built here, so pytorch/pytorch would be a source nothing reads. \
         One point, because the binding's version axis has one point."
      ();
    Canary_project_spec.artifact_row ~artifact:Canary_artifact.a_lib
      ~universe:
        [ ( SC.Fetched
              (SC.Lang_pkg
                 { lang = Canary_lang.OCaml; pm = Canary_store.Opam;
                   package = "libtorch"; self_contained = false;
                   versions =
                     Some [ { SC.pin_version = libtorch_pin;
                              install_name = Some libtorch_opam_pkg } ] }),
            [ Canary_basic.Stable ] ) ]
      ~rationale:
        "ONE POINT TODAY, and the missing one is known and named. \
         stable = opam libtorch.2.1.2+linux-x86_64 — the first lib in the \
         registry whose stable point is opam rather than the system PM, \
         because the package just unzips an official upstream binary \
         (174 MB, 694 MB unpacked) and no distro ships libtorch. \
         The LATEST point is upstream's own 2.2.1 zip \
         (download.pytorch.org, the sourcing rule's step 2 — the first \
         project in the registry where step 2 applies rather than falling \
         through to conda-forge), and it MUST be Vendored rather than \
         Fetched: torch declares conflicts libtorch {< 2.1.0 | >= 2.2.0}, \
         so `opam install torch libtorch.2.2.1` answers \
         'No solution found' — the solver will not let the mismatch world \
         exist inside opam. Placing 2.2.1 outside opam is what makes the \
         cell reachable, and that cell is the project's point: a deploy \
         mismatch the package manager DECLARES and the loader permits. \
         It is not realized yet (Canary_prebuilt handles .conda and \
         .tar.bz2, not .zip, and the binding must be rebuilt against the \
         other lib rather than repointed) — so the lib-pair warning from \
         spec-check is CORRECT and means this landing is not finished."
      ();
    Canary_project_spec.artifact_row ~artifact:torch_binding_art
      ~universe:
        [ ( SC.Fetched
              (SC.Lang_pkg
                 { lang = Canary_lang.OCaml; pm = Canary_store.Opam;
                   package = "torch"; self_contained = false;
                   versions =
                     Some
                       [ { SC.pin_version = torch_pin_stock;
                           install_name = None };
                         { SC.pin_version = torch_pin_patched;
                           install_name = None } ] }),
            [ Canary_basic.Stable ] ) ]
      ~rationale:
        "TWO POINTS, BUT NOT A CHANNEL PAIR — read this before trusting \
         spec-check's binding-pair count. The VERSION axis has exactly one \
         point: on OCaml 5.4.1, v0.17.0 is the only installable torch \
         (v0.16.0 and the 0.x series need base/core < v0.17, which needs \
         ocaml < 4.12.0; opam answers 'No solution found' for both, \
         measured). The two points here are the same upstream version \
         packaged differently: the STOCK package, which does not build \
         with dune 3.23.1 and is a declared build xfail, and a \
         CANARY-LOCAL patched package carrying the one-line upstream fix \
         so the lib axis has a consumer that can run. They answer 'does \
         this package build here', not 'does today's binding work with \
         tomorrow's lib'."
      () ]

(* ── realization ── *)

(* Which binding packaging this world asked for. *)
let binding_pin_of (a : Canary_artifact.assignment) : string =
  let v = Canary_enumerate.version_of a torch_binding_art in
  if String.is_empty v.Canary_basic.id then
    failwith "torch realize: binding placement carries no pin"
  else v.Canary_basic.id

let is_patched (pin : string) : bool = String.equal pin torch_pin_patched

(* opam's libtorch unpacks into the switch, so the libdir is a switch
   query rather than a declared path — asked at run time through the
   prologue's switch, never from the ambient environment. *)
let libtorch_root = "$(opam var prefix)/lib/libtorch"
let libtorch_libdir = libtorch_root ^ "/lib"

(* libtorch_cpu.so is the 438 MB implementation; libtorch.so is a 7 KB
   stub that only pulls it in, so every probe names the one that answers. *)
let libtorch_so = libtorch_libdir ^ "/libtorch_cpu.so"

(* The world assertion for the LIB (landing.md §3c: a world must NAME what
   answered). Unlike zlib, libtorch can state its own version — it ships a
   `build-version` file beside the libdir — so the check reads the
   artifact's own claim rather than a path we hoped for. *)
let libtorch_world_check =
  Printf.sprintf
    "test -f %s/build-version || { echo 'WORLD: libtorch build-version \
     missing at %s' >&2; exit 1; }\n\
     grep -qF '2.1.2' %s/build-version || { echo \"WORLD MISMATCH: \
     libtorch build-version $(cat %s/build-version), scenario declares \
     2.1.2\" >&2; exit 1; }\n"
    libtorch_root libtorch_root libtorch_root libtorch_root

let realize (a : Canary_artifact.assignment) : SB.runner_spec =
  let pin = binding_pin_of a in
  let opam_spec =
    Canary_toolchain.mk_opam_package_spec
      ~install_name:(Printf.sprintf "torch.%s" pin) ()
  in
  { SB.empty_runner_spec with
    stores =
      { SC.empty_store_config with
        lib =
          Some
            { SC.provider =
                SC.Lang_pkg
                  { lang = Canary_lang.OCaml; pm = Canary_store.Opam;
                    package = "libtorch"; self_contained = false;
                    versions =
                      Some [ { SC.pin_version = libtorch_pin;
                               install_name = Some libtorch_opam_pkg } ] };
              components = []; headers = None } };
    (* THE LIB IS AN OPAM INSTALL. Every other project's fetch_lib is an
       apt/brew call derived from a Sys_pkg; torch's is a Lang_pkg fetch
       for a NATIVE artifact, so the command is written here rather than
       derived — the shape the store_config's Derived path does not cover
       yet (it resolves Sys_pkg only). *)
    fetch_lib =
      Some
        (SB.Raw
           (fun ~output_dir ~variant_key ->
             let marker = Canary_basic.filename ~variant_key ~base:"lib" ~ext:"ok" in
             (* routed through the opam PM driver rather than spelled here
                (the tool-routing ratchet): the verb belongs to
                [Canary_pm_opam], the marker to the step *)
             Printf.sprintf "%s && echo 'installed' > %s/%s"
               (Canary_pm_opam.install_cmd ~pkg:libtorch_opam_pkg)
               output_dir marker));
    fetch_binding =
      [ (Canary_lang.OCaml,
         SB.Raw
           (fun ~output_dir ~variant_key ->
             (* the canary-local repo must be registered before the
                patched package is resolvable; harmless for the stock
                pin, so it is unconditional rather than branched *)
             (* [opam config subst] first, per the repo convention: only
                the .in template is COMMITTED (the materialised `opam` is
                gitignored, so a package dir can never shadow an official
                one by accident — the CLAUDE.md rank-1 gotcha). torch's
                template has no %{}% variables, so the subst is a copy;
                it is spelled the same way as every other canary package
                so the convention has one shape. *)
             let repo =
               "eval $(opam env) && \
                opam config subst \
                  canary/templates/opam-local-repo/packages/torch/\
                torch.v0.17.0-canary1/opam && \
                { opam repo add canary-local \
                  \"file://$PWD/canary/templates/opam-local-repo\" --rank=1 \
                  2>/dev/null || opam repo set-url canary-local \
                  \"file://$PWD/canary/templates/opam-local-repo\" ; } && \
                opam update canary-local && "
             in
             repo ^ SB.fetch_binding_cmd opam_spec ~output_dir ~variant_key)) ];
    check_post =
      (function
      | Canary_basic.Fetch (Canary_basic.Binding Canary_lang.OCaml) ->
          Some (SB.pin_check_post ~pkg:"torch" ~pin ~marker:"binding.ok")
      | _ -> None);
    probe_lib =
      [ ( Canary_store.Pm
            (Canary_store.Lang_pm
               { lang = Canary_lang.OCaml; pm = Canary_store.Opam }),
          fun ~output_dir ~variant_key ->
            libtorch_world_check
            ^ AN.native_lib_probe_cmd ~lib:libtorch_so ~prefix:"_ZN2at"
                ~output_dir ~variant_key ) ];
    probe_binding =
      [ ( Canary_lang.OCaml,
          Canary_store.Pm
            (Canary_store.Lang_pm
               { lang = Canary_lang.OCaml; pm = Canary_store.Opam }),
          fun ~output_dir ~variant_key ->
            let world =
              Canary_world.pre_shell
                [ Canary_world.Opam_pin { pkg = "torch"; version = pin } ]
            in
            world ^ libtorch_world_check
            ^ SB.probe_ocaml_cmd ~binding_lib:"torch"
                ~example:"canary/examples/torch/torch_example.ml"
                ~target:"torch_example" ~output_dir ~variant_key ) ];
    inspect =
      (fun action _loc ->
        match action with
        | Canary_basic.Probe_lib ->
            Some
              (fun ~output_dir ~variant_key ->
                AN.inspect_cmd ~lib:libtorch_so ~prefixes:torch_native_prefixes
                  ~watchlist:torch_native_watchlist ~output_dir ~variant_key ())
        | Canary_basic.Fetch (Canary_basic.Binding Canary_lang.OCaml) ->
            Some
              (fun ~output_dir ~variant_key ->
                Canary_artifact_lang.mli_inspect_opam_pkg_cmd ~pkg:"torch"
                  ~watchlist:torch_ocaml_watchlist ~output_dir ~variant_key ())
        | _ -> None);
    (* THE FINDING AS AN EXPECTATION. The stock package's fetch_binding
       fails: opam builds it and dune cannot stage torch_api_generated.cpp.
       Declared, so the run records an xfail with the reason rather than a
       red cell someone has to go read a log to understand. The patched
       pin has no such expectation and must pass. *)
    expectation =
      (fun action _loc ->
        match action with
        | Canary_basic.Fetch (Canary_basic.Binding Canary_lang.OCaml)
          when not (is_patched pin) ->
            Canary_step_model.Expect_failure
              { contains_any = [ "torch_api_generated.cpp" ];
                version_info = None }
        (* AND ITS CONSEQUENCE — with the substring the run actually
           prints, which is not the one guessed first. The stock world's
           install fails, so the switch never comes to hold v0.17.0, and
           the probe stops at its own WORLD ASSERTION rather than at
           ocamlfind:

             WORLD MISMATCH: switch has torch v0.17.0-canary1,
                             scenario declares torch v0.17.0

           That is the assertion working, and it is worth declaring
           precisely rather than as a bare ✗ someone must read a log to
           understand. Note what this xfail does and does not say: the
           world could not be ESTABLISHED, so its probe tested nothing —
           it is a consequence marker, not an independent finding. The one
           finding here is the build failure above. *)
        | Canary_basic.Probe_binding Canary_lang.OCaml
          when not (is_patched pin) ->
            Canary_step_model.Expect_failure
              { contains_any = [ "WORLD MISMATCH" ]; version_info = None }
        | _ -> Canary_step_model.Expect_success) }

let torch_run : Canary_project_run.project_run =
  { Canary_project_run.pr_name = "torch";
    pr_artifacts = torch_rows;
    pr_runner_spec = (fun a ~workspace:_ () -> realize a);
    pr_mismatch_probes = [];
    pr_wrapper_pkgs = [];
    pr_api_source = Some torch_api_source;
    pr_binding_decls = torch_binding_decls;
    pr_raw_build_overrides = [];
    pr_tier = Canary_project_run.Light }

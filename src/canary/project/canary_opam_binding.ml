open Canary_basic
open Canary_toolchain

(* ── The ocaml/opam binding pattern ──
   Renamed from "Pattern A" (Canary_pattern_a) 2026-08-17: the old name
   read like a project name; this is THE binding PATTERN — an OCaml/opam
   binding over a system C library via the `conf-*` virtual package.
   Examples: zarith via conf-gmp, ssl via conf-libssl, cairo2 via
   conf-cairo, etc.

   Layer note: this is the PROJECT layer's opam-side pattern (project
   declarations + realizations). The TOOL layer's opam PM driver is
   [Canary_pm_opam] (src/canary/tool/) — opam as a package manager
   (presence checks, install commands). Distinct concerns, distinct
   layers; wrapper-package generation (Publish) is the tool-layer
   half (see doc/canary/design/wrapper_packages.md §4).

   This module compresses the boilerplate. A new ocaml/opam-binding
   project becomes ~25 lines of declaration vs. ~100 lines of
   hand-rolled runner_spec. Extracted from zarith + ssl as the
   second-data-point validation per doc/canary/project/projects.md §4
   sequencing.

   Coverage boundaries:
   - This template covers native_lib + ocaml binding probe only. Projects with
     additional probe variants (e.g. sqlite's stdlib pip probe, llvm's
     llvmlite pip probe) extend the resulting runner_spec rather than fitting
     it through the template.
   - Optional-C-dep cases (lwt + conf-libev) are NOT yet covered; would need
     a `with_optional_lib` extension.
   - Self-building (like z3) is out of scope. *)

(* Per-project lib locator: enough info to produce a shell snippet that
   resolves $LIB_NATIVE on Linux (multilib path) and macOS (brew keg). *)
type lib_locator = {
  linux_glob : string;     (* e.g. "/usr/lib/x86_64-linux-gnu/libgmp.so*"
                              or "/usr/lib/x86_64-linux-gnu/libssl.so.*" *)
  brew_pkg : string;       (* e.g. "gmp" or "openssl@3" — for $(brew --prefix ...) *)
  brew_dylib : string;     (* basename under brew prefix's lib dir, e.g. "libgmp.dylib" *)
}

(* The full ocaml/opam-binding declaration. *)
type t = {
  name : string;                    (* "zarith" — project tag, dir name *)
  opam_pkg : string;                (* opam package; binding to install *)
  ocamlfind_pkg : string;           (* usually = opam_pkg; can differ (e.g. llvm) *)
  system_pkg_linux : string;        (* apt name, e.g. "libgmp-dev" *)
  system_pkg_macos : string;        (* brew name, e.g. "gmp" *)
  example_file : string;            (* path to canary/examples/<name>/<name>_example.ml *)
  example_target : string;          (* compile target name, e.g. "zarith_example" *)
  binding_lib : string;             (* `ocamlfind -package <binding_lib>`, usually = ocamlfind_pkg *)
  lib : lib_locator;                (* native lib resolution *)
  native_probe_prefix : string;     (* prefix for the count-symbols probe, e.g. "__gmp" / "SSL_" *)
  native_inspect_prefixes : string list; (* by_prefix breakdown for summary *)
  native_watchlist : string list;   (* hand-curated stable C symbols *)
  ocaml_module_watchlist : string list; (* hand-curated OCaml module names *)
  (* The declared source repos (2026-08-13 spec-check fulfillment; 2026-08-16
     C1 — the 3-way): per-channel repos, stable listed first, then dev, then
     a labeled fork when one exists. Non-empty = the runner_spec gains a
     fetch_source step (worktree checkouts) and the artifact table carries a
     source row whose store pins are the repos' own version records — each
     scenario materializes ITS channel's worktree. *)
  sources : Canary_artifact_source.source_repo list;
  (* WHOSE source [sources] is (2026-08-19, user: "a ref is used to mark a
     source who provides a lib or a binding"). Pattern A projects differ:
     cairo/libffi declare the C LIB's repo (cairo/cairo.git,
     libffi/libffi.git), while zarith declares the OCaml BINDING's repo
     (ocaml/Zarith.git — its C lib is apt libgmp). Both used to land in
     [a_source], so the matrix's ref column claimed zarith's binding repo
     was the project's lib source. [None] = the lib's source (the
     default); [Some lang] = that binding's source, which enumerates as
     [a_binding_source lang] and fetches through the
     [Fetch (Binding_source lang)] action. *)
  source_of_binding : Canary_lang.lang option;
  (* The binding's honest mechanism (2026-08-13, the recorded M2 issue):
     [Cstubs] for static stub-linked bindings (zarith/cairo), [Ctypes] for
     genuinely Dynamic_ffi ones (libffi's ctypes-foreign resolves and
     calls C at runtime). *)
  binding_mechanism : Canary_mechanism.mechanism;
  (* THE PACKAGE-MANAGER GATE (2026-08-19, user): how this binding's opam
     package declares its dependency on the C lib, measured from
     `opam show <pkg> --field=depends`. It is what decides how hard the
     project's 2×2 is — see [Canary_binding_decl.combination_freedom_of]:
     a conf-* with no constraint is free, a bound is free inside it, an
     exact pin needs a wrapper that drops the conf dep. *)
  pm_gate : Canary_binding_decl.pm_dep_gate;
  (* THE LIB'S LATEST POINT (2026-08-19, user's sourcing rule — see
     project/landing.md §3). stable is always the system PM; when a
     prebuilt LATEST is obtainable the project declares it here and the
     lib axis becomes a real pair (Fetched@Stable + Vendored@Dev).
     [None] = no pair is possible, and the row's rationale must say why
     (apt already ships upstream's newest, as with GMP). *)
  prebuilt_latest : Canary_prebuilt.t option;
  (* DOES THE PROBE NAME THE LIB IT RESOLVED? (2026-08-20, the zlib
     landing.) A Vendored world repoints LD_LIBRARY_PATH at the prebuilt,
     but nothing checked that the loader obeyed — cairo passes identically
     either way, which is how the missing repoint stayed invisible until
     someone read the command. When the example prints the resolved
     library path (the /proc/self/maps convention: `zlib resolved: <path>`),
     set this and the vendored probe ASSERTS the printed path is inside the
     prebuilt's libdir. That turns "the loader silently fell back to the
     system copy" from a passing run into a failing one.

     [false] = the probe prints no such line, so the vendored world is
     pointed but not asserted — an honest gap, visible in the declaration
     rather than buried in the runner. *)
  probe_names_lib : bool;
  (* The wrapper package (2026-08-17, active plan 2): when [Some], the
     bind_built scenarios gain a PUBLISH step installing this
     conf-free wrapper over the scenario's worktree (the pattern's
     Publish — pr_wrapper_pkgs derives from it), and the Fetched-binding
     probe gains the store-dance world check (the wrapper shares the
     findlib name, so the later opam probes must verify + restore the
     stock package). [None] = no wrapper (cairo/libffi — the classic
     conf-only shape). *)
  wrapper : Canary_opam_template.wrapper_decl option;
}

(** The artifact the declared [sources] provide — the lib's source by
    default, a binding's source when the project says so
    ([source_of_binding]). The enumeration, the artifact table and the
    matrix's setting block all read this one answer. *)
let source_artifact_of (d : t) : Canary_artifact.artifact_info =
  match d.source_of_binding with
  | None -> Canary_artifact.a_source
  | Some lang -> Canary_artifact.a_binding_source lang

(* Build the lib resolve shell snippet. Sets $LIB_NATIVE. *)
let lib_resolve (l : lib_locator) =
  Printf.sprintf
    {|LIB_NATIVE=$(ls %s 2>/dev/null \
        "$(brew --prefix %s 2>/dev/null)/lib/%s" 2>/dev/null \
        | head -1)
test -n "$LIB_NATIVE" -a -e "$LIB_NATIVE"|}
    l.linux_glob l.brew_pkg l.brew_dylib

let ocaml_config (d : t) : ocaml_tool_config =
  {
    toolchain =
      {
        prefix_name = String.uppercase_ascii d.name ^ "_PREFIX";
        prefix_var = "$" ^ String.uppercase_ascii d.name ^ "_PREFIX";
        prefix_envar = "${" ^ String.uppercase_ascii d.name ^ "_PREFIX}";
        libdir_name = String.uppercase_ascii d.name ^ "_LIB_DIR";
        libdir_var = "$" ^ String.uppercase_ascii d.name ^ "_LIB_DIR";
        local_repo_name = "canary-local";
        package_name = d.opam_pkg;
        package_version = "system";
        canary_src_var = "CANARY_" ^ String.uppercase_ascii d.name ^ "_SRC";
      };
    ocaml =
      {
        example_file = d.example_file;
        example_target = d.example_target;
        example_name = d.name ^ " example";
        binding_lib_name = d.binding_lib;
        build_api_path = None;
      };
    prebuilt =
      Some
        (mk_prebuilt_info ~opam_package:d.opam_pkg
           ~system_package_linux:d.system_pkg_linux
           ~system_package_macos:d.system_pkg_macos ());
  }

let runner_spec_with ?(vendored_lib : Canary_prebuilt.t option)
    (d : t) (src : Canary_artifact_source.source_repo option) :
    Canary_step_builder.runner_spec =
  let cfg = ocaml_config d in
  let prebuilt = prebuilt_info_exn cfg in
  let pm = Canary_store.detect_pm () in
  (* WHICH lib this world consumes (2026-08-19): the system PM's by
     default; the PREPARED prebuilt in a Vendored world. The whole point
     of the pair is that these are different bytes, so the resolve must
     differ too — a Vendored world that silently resolved the system lib
     would be the stable world wearing another name (the same class as
     the staged-probe lie the Installed axis had to fix). *)
  let resolve =
    match vendored_lib with
    | None -> lib_resolve d.lib
    | Some pb ->
        let dir = Canary_prebuilt.libdir_of pb (Canary_basic.detect_distro ()) in
        (* the hint used to wrap the command in BACKTICKS inside a
           double-quoted shell string, so sh ran `canary prebuilt zlib` as
           command substitution: the guard fired correctly and then printed
           "run  first" over a stray "sh: canary: not found" (2026-08-20,
           surfaced by deliberately breaking the libdir to falsify the
           world assert). A diagnostic that destroys itself is the same
           class as the checks in landing.md §4 — single quotes now. *)
        Printf.sprintf
          "LIB_NATIVE=$(ls %s/%s 2>/dev/null | head -1)\n\
           test -n \"$LIB_NATIVE\" -a -e \"$LIB_NATIVE\" || { echo \
           \"PREBUILT MISSING: %s — run 'canary prebuilt %s' first\" >&2; \
           exit 1; }"
          (Canary_prebuilt.path_of pb (Canary_basic.detect_distro ()))
          pb.Canary_prebuilt.lib_glob dir pb.Canary_prebuilt.project
  in
  {
    Canary_step_builder.empty_runner_spec with
    (* Declarative lib store (S3/S4): fetch_lib is Derived from this. *)
    stores =
      { Canary_store_config.empty_store_config with
        lib = Some
          { Canary_store_config.provider =
              Canary_store_config.Sys_pkg prebuilt.system_package;
            components = []; headers = None } };
    fetch_lib = Some (Canary_step_builder.Derived Canary_step_builder.Fetch_lib);
    (* The declared source made runnable via WORKTREE checkouts
       (2026-08-15, design/enumeration/stage1_project_spec.md): the fetch IS the prepare —
       clone once + a worktree per ref into the contrib tree
       ([Canary_store.contrib_root]), refreshed on demand each run.
       [src] is the SCENARIO's repo (the per-channel dispatch, C1) —
       the pattern never builds from it. *)
    (* the fetch lands in the slot for the artifact the source PROVIDES
       (2026-08-19): a lib source fetches through [Fetch Source], a
       binding's through [Fetch (Binding_source lang)] — same command,
       different action, so the step's gating and its marker follow the
       artifact the project actually declared. *)
    fetch_source =
      (match d.source_of_binding with
       | Some _ -> None
       | None ->
           Option.map
             (fun source ~output_dir ~variant_key ->
               Canary_artifact_source.worktree_ensure_cmd ~project:d.name
                 ~repo:source ~ref_:source.ref_ ~output_dir ~variant_key ())
             src);
    fetch_binding_source =
      (match (d.source_of_binding, src) with
       | Some lang, Some source ->
           [ ( lang,
               fun ~output_dir ~variant_key ->
                 Canary_artifact_source.worktree_ensure_cmd
                   ~marker:"binding_source.ok" ~project:d.name ~repo:source
                   ~ref_:source.ref_ ~output_dir ~variant_key () ) ]
       | _ -> []);
    (* fetch_binding stays Raw (Derived can't reproduce opam install_args yet). *)
    fetch_binding =
      [ (Canary_lang.OCaml, Canary_step_builder.Raw (Canary_step_builder.fetch_binding_cmd prebuilt.opam_package_spec)) ];
    probe_lib =
      [ ( Canary_store.Pm (Canary_store.Sys_pm { pm }),
          fun ~output_dir ~variant_key ->
            let probe = Canary_artifact_native.native_lib_probe_cmd
              ~lib:"$LIB_NATIVE" ~prefix:d.native_probe_prefix ~output_dir ~variant_key in
            Printf.sprintf "%s\n%s" resolve probe ) ];
    (* NOTE: [runner_spec_for] REBUILDS probe_binding per scenario (the
       world-check + the vendored env), so this entry is the
       assignment-less default only — do not put per-world logic here, it
       would be discarded. (Learned the hard way 2026-08-19: an edit here
       looked right and never ran.) *)
    probe_binding =
      [
        (Canary_lang.OCaml,
         Canary_store.Pm (Canary_store.Lang_pm { lang = Canary_lang.OCaml; pm = Canary_store.Opam }),
         (fun ~output_dir ~variant_key ->
           Canary_step_builder.probe_ocaml_cmd ~binding_lib:d.binding_lib
             ~example:d.example_file ~target:d.example_target
             ~output_dir ~variant_key));
      ];
    inspect = (fun action loc -> match action, loc with
      | Probe_lib, _ ->
          Some (fun ~output_dir ~variant_key ->
            let sum = Canary_artifact_native.inspect_cmd
              ~lib:"$LIB_NATIVE"
              ~prefixes:d.native_inspect_prefixes
              ~watchlist:d.native_watchlist
              ~output_dir ~variant_key () in
            Printf.sprintf "%s\n%s" resolve sum)
      | Probe_binding (_), _ ->
          Some (fun ~output_dir ~variant_key ->
            Canary_artifact_lang.inspect_opam_pkg_cmd
              ~pkg:d.ocamlfind_pkg
              ~watchlist:d.ocaml_module_watchlist
              ~output_dir ~variant_key ())
      | _ -> None);
  }

(* The module-level default realization: the STABLE repo (head of
   [sources]) — the CI entry (`no_source <Mod>.runner_spec`) and tests.
   The per-scenario dispatch lives in [run] below. *)
let runner_spec (d : t) : Canary_step_builder.runner_spec =
  match d.sources with
  | s :: _ -> runner_spec_with d (Some s)
  | [] -> runner_spec_with d None

(* The repo backing one scenario's source placement (C1, 2026-08-16): the
   source row's store pins carry each repo's (channel, id), so match the
   placement's version against the declared repos — exact (channel, id)
   first, then channel-only (ambient placements), then the stable head.
   The realize ∘ dispatch idiom (canary_project_z3.ml). *)
let source_for_assignment (d : t) (a : Canary_artifact.assignment) :
    Canary_artifact_source.source_repo =
  (* read the placement of the artifact THESE repos provide (2026-08-19):
     the lib's source, or a binding's when the project declares one —
     reading [a_source] unconditionally left zarith's dispatch with an
     absent placement and it fell through to the stable head, so every
     scenario fetched the 1.14 worktree. *)
  let v = Canary_enumerate.version_of a (source_artifact_of d) in
  let open Canary_basic in
  match
    List.find_opt
      (fun r ->
        equal_channel r.Canary_artifact_source.version.channel v.channel
        && String.equal r.Canary_artifact_source.version.id v.id)
      d.sources
  with
  | Some r -> r
  | None -> (
      match
        List.find_opt
          (fun r ->
            equal_channel r.Canary_artifact_source.version.channel v.channel)
          d.sources
      with
      | Some r -> r
      | None -> (
          match d.sources with
          | s :: _ -> s
          | [] ->
              failwith
                "opam_binding source_for_assignment: no source declared"))

(* The pattern's forward-cell contract (2026-08-17, active plan 1): c1 —
   symbol set. When the binding is BUILT and the lib is FETCHED (the
   forward cell: new binding × old lib), the probe's failure must be a
   PREDICTED compat finding (the stub's undefined C symbols vs the
   lib's exports — the tiny-full precedent), not a raw FAIL. The other
   cells keep Expect_success. *)
let opam_binding_contract_bindings : Canary_scenario.contract_binding list =
  let module CC = Canary_compat in
  let module CS = Canary_scenario in
  [ { contract = CC.C1; lang = Canary_lang.OCaml;
      firings = [
        { site = CS.At_probe_binding Canary_lang.OCaml;
          loc_filter = CS.Any;
          source = CS.From_artifact {
            inputs = Canary_compat_run.inputs_of_contract CC.C1 Canary_lang.OCaml;
            version_info = None;
          }};
      ]} ]

(* The per-scenario realization (2026-08-17): the dispatch over the base
   [runner_spec_with] —
   - binding Built (the FORWARD cell: new binding over the system lib)
     → build_binding (the scenario's worktree copied into the shared
     build dir — the checkout stays pristine — configure+make, which
     finds the system lib naturally) + a Build_tree probe.
   The LIB side stays Fetched only — the prebuilt-shadows-source rule
   (user feedback, 2026-08-17): building an external C lib (GMP's hg
   tree: bootstrap + libtool + VPATH traps) is a LAST resort, reserved
   for fixing the lib or confirming a blame. A second lib version
   enters only as a prebuilt (the shadow-preference mechanism,
   conf_survey.md §6); until one exists, the lib axis is the system
   PM's stable. *)
let runner_spec_for (d : t) (a : Canary_artifact.assignment) :
    Canary_step_builder.runner_spec =
  let src = source_for_assignment d a in
  let distro = Canary_basic.detect_distro () in
  let bind_built =
    Canary_enumerate.equal_provision
      (Canary_enumerate.provision_of a
         (Canary_artifact.a_binding Canary_lang.OCaml d.binding_mechanism))
      Canary_artifact.Built
  in
  let vendored_lib =
    match
      ( d.prebuilt_latest,
        Canary_enumerate.provision_of a Canary_artifact.a_lib )
    with
    | Some pb, Canary_artifact.Vendored -> Some pb
    | _ -> None
  in
  let base = runner_spec_with ?vendored_lib d (Some src) in
  (* the shared build tree for a Built binding (2026-08-17 fix): the
     build_binding and probe_binding steps have DIFFERENT output dirs
     (projects/<p>/<step>/<lang>/), so a build dir keyed on [output_dir]
     alone is invisible to the probe. Both closures compute the SAME dir
     from their own output_dir: two levels up = the project dir (Output
     Layout v3: projects/<p>/<step>/<lang>/). *)
  let ws_src_dir output_dir variant_key =
    Printf.sprintf "%s/../../src_%s" output_dir variant_key
  in
  let build_binding =
    if bind_built then
      [ (Canary_lang.OCaml,
         fun ~output_dir ~variant_key ->
           let wt =
             Canary_artifact_source.repo_worktree_path ~project:d.name
               ~repo:src ~ref_:src.Canary_artifact_source.ref_ distro
           in
           let s = ws_src_dir output_dir variant_key in
           (* the c1 summaries (active plan 1): the forward cell's compat
              inputs resolve from the STEP-DIR summaries the runner's
              resolve_input reads — the stub summary at
              projects/<p>/build_binding/ocaml/ (the step's OWN dir: the
              binding's c1 input is [build_binding_ocaml/inspect.json],
              which step_dir_of_tag maps to the lang dir) and the SYSTEM
              lib's native summary at projects/<p>/build_lib/ (lang-less
              — the input [build_lib/inspect.json] maps to it directly).
              The lib summary is the same inspect the probe_lib_inspect
              produces — written here too because the resolver only
              looks at build_lib/. *)
           let stub_sum =
             (* inline the python call — the [stub_inspect_pipe_cmd] helper
                single-quotes its path (for literal paths), which would pass
                the LITERAL "$STUB" to nm *)
             Printf.sprintf
               "STUB=$(ls %s/*.a 2>/dev/null | head -1)\n\
                test -n \"$STUB\"\n\
                python3 canary/scripts/inspect_binding.py --kind stub \
                  --path \"$STUB\" --prefix '%s' --watchlist '' > %s/%s"
               s d.native_probe_prefix output_dir
               (Canary_basic.filename ~variant_key ~base:"inspect" ~ext:"json")
           in
           let lib_sum =
             let pipe =
               Canary_artifact_native.inspect_pipe_cmd ~lib:"$LIB_NATIVE"
                 ~prefixes:d.native_inspect_prefixes ()
             in
             (* mkdir the summary dir: this scenario has NO build_lib step
                (the lib is Fetched — system gmp), and [exec_step] only
                creates the step's OWN dir, so a COLD run has no
                build_lib/ to redirect into (the warm cache masked it —
                old runs left the dir behind; the 2026-08-17 cold-run
                audit caught the redirect dying with "Directory
                nonexistent") *)
             Printf.sprintf "mkdir -p %s\n%s\n%s > %s/%s"
               (output_dir ^ "/../../build_lib")
               (lib_resolve d.lib) pipe
               (output_dir ^ "/../../build_lib")
               (Canary_basic.filename ~variant_key ~base:"inspect" ~ext:"json")
           in
           (* the binding builds against the SYSTEM lib (the prebuilt-
              shadows-source rule — no source-built lib column). The
              summaries run from the REPO ROOT (cd "$OLDPWD" — the
              inspect scripts' paths are repo-root-relative) *)
           Printf.sprintf
             "eval $(opam env) && rm -rf %s && cp -r %s %s && cd %s && \
              ./configure && make && cd \"$OLDPWD\" && %s && %s"
             s wt s s stub_sum lib_sum
           |> Canary_build_cmd.with_marker ~marker:"build.ok" ~output_dir
                ~variant_key)
      ]
    else []
  in
  (* the store dance's world-check half (2026-08-17, active plan 2):
     the forward cell (sorted FIRST among the dev worlds) publishes the
     wrapper under the same findlib name; a LATER opam probe must verify
     the store holds the STOCK package (the stable repo's version id)
     and self-heal by reinstalling it when not — each scenario lands
     itself in the right world (enumeration/stage4_order.md §2, in-run
     instead of next-run). *)
  let stable_id =
    match
      List.find_opt
        (fun r ->
          Canary_basic.equal_channel
            r.Canary_artifact_source.version.Canary_basic.channel
            Canary_basic.Stable)
        d.sources
    with
    | Some r -> r.Canary_artifact_source.version.Canary_basic.id
    | None -> ""
  in
  let world_check =
    match (d.wrapper, stable_id) with
    | Some _, id when not (String.equal id "") ->
        Printf.sprintf
          "eval $(opam env)\n\
           INSTALLED=$(opam list %s --installed --short --columns=version 2>/dev/null)\n\
           test \"$INSTALLED\" = \"%s\" || %s\n"
          d.opam_pkg id
          (Canary_pm_opam.install_cmd ~pkg:(d.opam_pkg ^ "." ^ id))
    | _ -> ""
  in
  let probe_binding =
    if bind_built then
      [ (Canary_lang.OCaml, Canary_store.Build_tree,
         fun ~output_dir ~variant_key ->
           let s = ws_src_dir output_dir variant_key in
           let log = Canary_basic.variant_file ~variant_key "probe.log" in
           (* NO cd — the example path is repo-root-relative (the opam
              probe's convention); the build dir enters via -I + the
              loader path (dllzarith.so loads from the build dir). *)
           let ld = "LD_LIBRARY_PATH=" ^ s ^ ":" in
           Printf.sprintf
             "eval $(opam env) && export %s && \
              ocamlfind ocamlopt -I %s %s/zarith.cmxa %s \
                -o %s/zarith_example > %s/%s 2>&1 && \
              %s/zarith_example >> %s/%s 2>&1 && cat %s/%s"
             ld s s d.example_file output_dir output_dir log
             output_dir output_dir log output_dir log)
      ]
    else
      [ (Canary_lang.OCaml,
         Canary_store.Pm
           (Canary_store.Lang_pm
              { lang = Canary_lang.OCaml; pm = Canary_store.Opam }),
         fun ~output_dir ~variant_key ->
           (* THE CONSUMER RUNS AGAINST THE WORLD'S LIB (2026-08-19). A
              plain `ocamlfind -package <pkg>` run resolves shared
              libraries the ambient way — the SYSTEM copy — so in a
              VENDORED world the consumer half was silently a duplicate of
              the fetched world's: both passed because both tested the
              same lib. Caught by reading the emitted command, not by a
              failure. Same class as z3's cross cells and sqlite's staged
              probe: put the world's libdir FIRST on LD_LIBRARY_PATH. *)
           match vendored_lib with
           | None ->
               world_check
               ^ Canary_step_builder.probe_ocaml_cmd
                   ~binding_lib:d.binding_lib ~example:d.example_file
                   ~target:d.example_target ~output_dir ~variant_key
           | Some pb ->
               world_check
               ^ Canary_step_builder.probe_ocaml_env_cmd
                   ~env:
                     [ Printf.sprintf "LD_LIBRARY_PATH=%s:$LD_LIBRARY_PATH"
                         (Canary_prebuilt.libdir_of pb distro) ]
                   (* assert the loader OBEYED the repoint, when the probe
                      says which file it resolved (2026-08-20) *)
                   ~log_grep:
                     (if d.probe_names_lib then
                        [ Canary_world.Log_names
                            { text = Canary_prebuilt.libdir_of pb distro;
                              why =
                                "the probe must report a library inside \
                                 this world's prebuilt libdir — \
                                 LD_LIBRARY_PATH is a preference, and a \
                                 loader that fell back to the system copy \
                                 would pass for the wrong reason" } ]
                      else [])
                   ~binding_lib:d.binding_lib
                   ~example:d.example_file ~target:d.example_target
                   ~output_dir ~variant_key)
      ]
  in
  let pack_binding =
    match (d.wrapper, bind_built) with
    | Some w, true ->
        [ ( Canary_lang.OCaml,
            fun ~output_dir ~variant_key ->
              (* the scenario's worktree = the wrapper's source — the
                 same tree the build_binding step copied from *)
              let wt =
                Canary_artifact_source.repo_worktree_path ~project:d.name
                  ~repo:src ~ref_:src.Canary_artifact_source.ref_ distro
              in
              Canary_pm_opam.pack_wrapper_cmd ~repo_name:"canary-local"
                ~repo_abs:"canary/templates/opam-local-repo"
                ~pkg:w.Canary_opam_template.pkg
                (* the repo dir: packages/<name>/<name>.<version> — the
                   name dir is the project's opam package *)
                ~pkg_dir:
                  (d.opam_pkg ^ "/" ^ w.Canary_opam_template.pkg ^ ".dev")
                ~src_var:w.src_var ~src_path:wt ~conflicts:w.conflicts
                ~output_dir ~variant_key () ) ]
    | _ -> []
  in
  { base with
    fetch_binding =
      (if bind_built then [] else base.Canary_step_builder.fetch_binding);
    build_binding; probe_binding; pack_binding;
    check_post =
      (fun action ->
        match (action, d.wrapper) with
        | ( Canary_basic.Fetch Canary_basic.Source, _ )
          when not
                 (String.equal src.Canary_artifact_source.ref_ "HEAD") ->
            (* the pinned-ref FRESHNESS check (2026-08-17, the warm-mask
               fix's residual class): the worktree must still be AT the
               declared ref — OFFLINE, via [rev-parse HEAD =
               <ref>^{commit}] (SHAs and tags alike). A moved checkout
               breaks the warm skip and the worktree_ensure re-pins it.
               HEAD-refs (master) can't be checked offline. *)
            Some
              (fun ~output_dir ~variant_key ->
                let ok_file =
                  output_dir ^ "/"
                  ^ Canary_basic.variant_file ~variant_key "source.ok"
                in
                let wt =
                  Canary_artifact_source.repo_worktree_path ~project:d.name
                    ~repo:src ~ref_:src.Canary_artifact_source.ref_
                    (Canary_basic.detect_distro ())
                in
                Stdlib.Sys.command
                  (Printf.sprintf
                     "test -f %s && r1=$(git -C %s rev-parse HEAD) && \
                      r2=$(git -C %s rev-parse '%s^{commit}') && \
                      [ \"$r1\" = \"$r2\" ]"
                     ok_file wt wt
                     src.Canary_artifact_source.ref_)
                = 0)
        | ( Canary_basic.Publish (Canary_basic.Binding Canary_lang.OCaml),
            Some w )
          when bind_built ->
            (* the publish's store mutation is verified, not just "ran":
               a warm-skipped publish only fires when the switch
               provably holds the wrapper (the z3.dev pin-check).
               Gated on [bind_built] — the Publish step only exists in
               the built-binding scenarios. *)
            Some
              (Canary_step_builder.pin_check_post ~pkg:w.Canary_opam_template.pkg
                 ~pin:"dev" ~marker:"pack.ok")
        | ( Canary_basic.Probe_binding Canary_lang.OCaml,
            Some _ )
          when (not bind_built) && not (String.equal stable_id "") ->
            (* the store dance's verification half: a warm-skipped opam
               probe may only fire when the switch provably holds the
               STOCK package (the stable version) — a warm skip after
               the publish (the wrapper sits in the store) fails this
               check and the probe re-runs, its world check
               reinstalling the stock package. Same doctrine as the
               pin-check: the marker alone is not the world. *)
            Some
              (Canary_step_builder.pin_check_post ~pkg:d.opam_pkg
                 ~pin:stable_id ~marker:"probe.log")
        | _ -> base.Canary_step_builder.check_post action);
    (* the forward cell's probe carries the c1 compat-derived
       expectation (active plan 1); the other cells keep success *)
    expectation =
      (if bind_built then
         Canary_scenario.lower_expectation_agnostic
           ~bindings:opam_binding_contract_bindings
           ~langs:[ Canary_lang.OCaml ]
       else base.Canary_step_builder.expectation);
  }

(* ── THE artifact table + run (2026-08-13, spec-check fulfillment) ──
   Typed rows replacing [Canary_project_run.simple]'s providerless rows:
   source (when declared) + system-pkg lib + opam binding — the spec
   audit reads providers off these rows. The runner_spec above is the
   realization (constant over the single scenario). *)

let artifacts (d : t) : Canary_project_spec.artifact_row list =
  let open Canary_artifact in
  (* The 2×2 matrix (2026-08-17): the binding's Built column appears when
     the project declares a DEV source (zarith master) — the forward cell
     (Built binding × Fetched lib) is a designed mismatch scenario, kept
     by [assignment_ok]'s source-channel coupling (the binding builds
     from ITS repo; only the source channel couples, the lib pairing
     stays "any lib"). *)
  let binding_universe =
    let dev =
      List.exists
        (fun r ->
          equal_channel r.Canary_artifact_source.version.Canary_basic.channel
            Canary_basic.Dev)
        d.sources
    in
    if dev then [ (Fetched, [ Canary_basic.Stable ]); (Built, [ Canary_basic.Dev ]) ]
    else [ (Fetched, [ Canary_basic.Stable ]) ]
  in
  let binding_row =
    Canary_project_spec.artifact_row
      ~artifact:(a_binding Canary_lang.OCaml d.binding_mechanism)
      ~universe:binding_universe
      ~provider:
        (Canary_store_config.Lang_pkg
           { lang = Canary_lang.OCaml; pm = Canary_store.Opam;
             package = d.opam_pkg; self_contained = false; versions = None })
      ()
  in
  (* the lib row: the system package's Fetched column ONLY — the
     prebuilt-shadows-source rule (2026-08-17): no source-built lib
     column; a second lib version enters as a prebuilt, never a build *)
  let lib_row =
    (* the lib's channel pair, sourced by the rule (landing.md §3):
       stable = the system PM, latest = a declared prebuilt when one is
       obtainable. The prebuilt point is [Vendored] — supplied, neither
       built here nor PM-resolved — and is PREPARED before any run
       (`canary prebuilt`), so no scenario depends on the network. *)
    let universe =
      match d.prebuilt_latest with
      | None -> [ (Fetched, [ Canary_basic.Stable ]) ]
      | Some _ ->
          [ (Fetched, [ Canary_basic.Stable ]);
            (Vendored, [ Canary_basic.Dev ]) ]
    in
    let rationale =
      match d.prebuilt_latest with
      | Some pb ->
          Printf.sprintf
            "lib pair: stable = the system PM (%s); latest = %s. %s"
            d.system_pkg_linux pb.Canary_prebuilt.tag pb.Canary_prebuilt.note
      | None ->
          Printf.sprintf
            "lib axis has ONE point (%s from the system PM): no prebuilt \
             latest is obtainable — see project/landing.md §3 for the \
             sourcing rule and why this lib has no second point."
            d.system_pkg_linux
    in
    Canary_project_spec.artifact_row ~artifact:a_lib ~universe ~rationale
      ~provider:
        (Canary_store_config.Sys_pkg
           { Canary_store.linux_pkg = d.system_pkg_linux;
             macos_pkg = d.system_pkg_macos; version_tag = None;
             locator_hint = None; behavior = Canary_store.Stateful_global })
      ()
  in
  let source_rows =
    match d.sources with
    | [] -> []
    | sources ->
        (* the source row's universe = the repos' channels (dedup'd); the
           store pins — projected from the [Repo_axes] provider (C1) —
           carry the concrete per-channel versions, so each channel's repo
           is an identity-bearing scenario *)
        let channels =
          List.sort_uniq Stdlib.compare
            (List.map
               (fun r -> r.Canary_artifact_source.version.Canary_basic.channel)
               sources)
        in
        [ Canary_project_spec.artifact_row
            ~artifact:(source_artifact_of d)
            ~universe:[ (Fetched, channels) ]
            ~provider:(Canary_store_config.Repo_axes sources) () ]
  in
  lib_row :: binding_row :: source_rows

let run (d : t) : Canary_project_run.project_run =
  { pr_name = d.name;
    pr_artifacts = artifacts d;
    (* per-scenario realization (C1): each scenario materializes ITS
       channel's source worktree — the dispatch reads the source
       placement's pinned version (the realize ∘ dispatch idiom) *)
    pr_runner_spec =
      (* C2.5 (2026-08-17): the 2×2 per-scenario realization — the Built
         columns get their build closures + build-tree probes, the deploy
         cell its LD_LIBRARY_PATH repoint *)
      (fun a ~workspace:_ () ->
        runner_spec_for d a);
    pr_mismatch_probes = [];
    (* active plan 2 (2026-08-17): the pattern's wrapper declaration —
       spec-check's dev_wrapper_package item reads it *)
    pr_wrapper_pkgs =
      (match d.wrapper with
      | Some w -> [ (Canary_lang.OCaml, w.Canary_opam_template.pkg) ]
      | None -> []);
    pr_api_source = None;
    pr_binding_decls = [];
    pr_raw_build_overrides = [];
    pr_tier = Canary_project_run.Light }

(** [Canary_build_cmd] — generic build-tool primitives.

    Wraps cmake / ninja / dune invocations plus the trailing marker-write
    pattern that canary's default check_post recognizes. Extracted from
    [Canary_toolchain] on 2026-06-01 (Phase 3 of the post-audit
    refactor): the cmake/ninja/dune helpers don't share concerns with
    opam/cc/python config types, so they live next to the project specs
    that consume them, not next to the OCaml-binding toolchain types.

    Each canary step that runs a build command needs to (1) run the
    command and (2) write a marker file canary's default check_post
    looks for ([conf.ok] / [build.ok] / [install.ok] / [pack.ok] /
    [probe.log]). [with_marker] appends step (2); the [_cmd] primitives
    produce step (1). *)

open Base

(** Write a marker file canary's default check_post looks for. Returns
    the shell snippet [echo 'ok' > <output_dir>/<variant-keyed marker>].
    [marker] is the canonical marker name for the action (conf.ok / build.ok
    / install.ok / pack.ok / probe.log). *)
let mark_step_complete ~output_dir ~variant_key marker =
  let f = Canary_basic.variant_file ~variant_key marker in
  Printf.sprintf "echo 'ok' > %s/%s" output_dir f

(** Compose a build command with the marker-write suffix that canary's
    default check_post recognizes. The full command becomes
    [<cmd> && echo 'ok' > <output_dir>/<variant marker>]. *)
let with_marker cmd ~marker ~output_dir ~variant_key =
  Printf.sprintf "%s && %s"
    cmd (mark_step_complete ~output_dir ~variant_key marker)

(** Single-line [cmake -S <src> -B <build> [flags]] configure command.
    [flags] is a list of additional CLI args (e.g. ["-G Ninja";
    "-DZ3_BUILD_OCAML_BINDINGS=ON"]) joined with spaces. [cmake_exec]
    lets callers prefix with [opam exec --] when the cmake binary must
    come from an opam switch. *)
let cmake_configure_cmd ?(cmake_exec = "cmake") ?(flags = []) ~src ~build () =
  let flag_str = String.concat ~sep:" " flags in
  if String.is_empty flag_str then
    Printf.sprintf "%s -S %s -B %s" cmake_exec src build
  else
    Printf.sprintf "%s -S %s -B %s %s" cmake_exec src build flag_str

(** Single-line [cmake --build <build> [--target <name>]] command.
    [cmake_exec] mirrors {!cmake_configure_cmd}. *)
let cmake_build_cmd ?(cmake_exec = "cmake") ?target ~build () =
  match target with
  | None -> Printf.sprintf "%s --build %s" cmake_exec build
  | Some t -> Printf.sprintf "%s --build %s --target %s" cmake_exec build t

(** Single-line [ninja -C <build> [<target>]] command. *)
let ninja_build_cmd ?(ninja_exec = "ninja") ?target ~build () =
  match target with
  | None -> Printf.sprintf "%s -C %s" ninja_exec build
  | Some t -> Printf.sprintf "%s -C %s %s" ninja_exec build t

(** Single-line dune build command. [env_extra] is a list of
    ["VAR=value"] pairs prepended to the command (e.g.
    [["LIBRARY_PATH=$PWD/c/build"; "LD_RUN_PATH=$PWD/c/build"]]).
    [target] is the dune build target (path or @alias); omitted = build
    everything in scope. [root] is the dune workspace root (passed via
    [--root <root>]); used by tiny variants whose materialized
    workspace lives outside the tola dune-project. *)
(* REAL install: the build system's own install step ("cmake --install
   <build> --prefix <prefix>") — applies the install-time transformations
   (config files, versioned symlinks, RPATH handling) a hand `cp` skips
   (TODO #40 / status §B build-config divergence). Caller owns the
   idempotence guard.

   SAFETY (user, 2026-08-06): a prefix is REQUIRED (labelled, no default)
   so no caller can omit it at compile time, AND the emitted shell guards
   against an EMPTY expansion at run time — a shell-var prefix ("$PREFIX")
   whose assignment went missing would otherwise fall back to
   CMAKE_INSTALL_PREFIX = /usr/local, a global-path install canary must
   never perform. (Fetch actions are the only intended global-store
   writes, per the PM's declared [Canary_store.store_behavior].) *)
let cmake_install_cmd ?(cmake_exec = "cmake") ?component ~build ~prefix () =
  let comp_flag = match component with Some c -> " --component " ^ c | None -> "" in
  Printf.sprintf
    "{ test -n \"%s\" || { echo 'cmake_install_cmd: empty prefix — refusing \
     global install'; exit 1; }; } && %s --install %s --prefix \"%s\"%s"
    prefix cmake_exec build prefix comp_flag

(* Fetch a zip archive and extract it into [dest] (curl + unzip). The
   caller owns idempotence guards; this is just the named verb pair so
   project specs don't hand-roll curl/unzip (tool-routing ratchet). *)
let curl_unzip_cmd ~url ~dest () =
  Printf.sprintf
    "mkdir -p %s && curl -sL %s -o %s/a.zip && (cd %s && unzip -oq a.zip)"
    dest url dest dest

(* Compile one C translation unit into a shared library. Defaults produce
   "gcc -shared -fPIC <src> -o <out> <ldlibs>"; guards/symlinks stay with
   the caller (project-shaped), the compiler verb lives here. *)
let cc_shared_lib_cmd ?(cc = "gcc") ?(flags = [ "-shared"; "-fPIC" ])
    ?(ldlibs = []) ~c_src ~out () =
  Printf.sprintf "%s %s %s -o %s %s" cc
    (String.concat ~sep:" " flags)
    c_src out
    (String.concat ~sep:" " ldlibs)

let dune_build_cmd ?(env_extra = []) ?root ?target () =
  let env_prefix = match env_extra with
    | [] -> ""
    | xs -> String.concat ~sep:" " xs ^ " " in
  let root_flag = match root with
    | None -> ""
    | Some r -> " --root " ^ r in
  match target with
  | None -> Printf.sprintf "%sdune build%s" env_prefix root_flag
  | Some t -> Printf.sprintf "%sdune build%s %s" env_prefix root_flag t

(** List the installed prefix layout (pc files, cmake configs, symlinks,
    directory tree) into a JSON inventory. Feeds the build-tree↔staged
    layout diff (§B build-config divergence slice (iii)). *)
let prefix_layout_inspect_cmd ~prefix ~output_dir ~variant_key =
  let out = output_dir ^ "/" ^ Canary_basic.variant_file ~variant_key "prefix_layout.json" in
  Printf.sprintf
    "{ find %s -type f -o -type l 2>/dev/null | sort | while read f; do \
     printf '{\"path\":\"%%s\",\"type\":\"%%s\",\"size\":%%d}' \
       \"${f#%s/}\" $(stat -c%%F \"$f\" 2>/dev/null || echo unknown) \
       $(stat -c%%s \"$f\" 2>/dev/null || echo 0); done; } > %s"
    prefix prefix out

(** Locate llvm-config across distros: try the configured hint name, fall
    back to bare "llvm-config", brew --prefix on macOS, absolute fallback.
    [locator_hint] is the package-specific name (e.g. "llvm-config-19"). *)
let llvm_config_cmd ~locator_hint ~macos_pkg =
  [%string
    "if command -v %{locator_hint} >/dev/null 2>&1; then command -v \
     %{locator_hint}; elif command -v llvm-config >/dev/null 2>&1; then \
     command -v llvm-config; elif command -v brew >/dev/null 2>&1; then printf \
     '%s\\n' \"$(brew --prefix \
     %{macos_pkg})/bin/%{locator_hint}\"; else \
     printf '%s\\n' %{locator_hint}; fi"]

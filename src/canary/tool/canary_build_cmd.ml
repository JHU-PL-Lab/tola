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
    [marker] is the canonical marker name for the rule (conf.ok / build.ok
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
    everything in scope. *)
let dune_build_cmd ?(env_extra = []) ?target () =
  let env_prefix = match env_extra with
    | [] -> ""
    | xs -> String.concat ~sep:" " xs ^ " " in
  match target with
  | None -> env_prefix ^ "dune build"
  | Some t -> Printf.sprintf "%sdune build %s" env_prefix t

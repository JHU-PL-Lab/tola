(** Mutation types and constructors for scenario-driven projects.

    Companion to [canary_artifact_native] / [canary_artifact_source]
    / [canary_artifact_lang] / [canary_artifact_api]: those describe
    how to {b inspect} each artifact; this one describes how to
    {b mutate} them.

    Extracted from [Canary_tiny_scenario] 2026-07-09. The current
    contents are {b tiny-flavoured} — [Patch] takes a
    [scenarios/patches/<name>] file path; [rebuild_target] mentions
    tiny's build steps. A second project taking on scenarios would
    either reuse these variants directly or extend the type. Full
    parametric mutation constructors (drop_symbol, bump_soname,
    …) will land alongside §7.2 recipe synthesis — see
    [doc/canary/design/tiny.md] §7.2.

    Layer note: this module sits in [tool/], one level below
    [action/] and [projects/], so both [Canary_scenario] and
    every [canary_project_*] can reference these types.

    Not to be confused with [Canary_scenario.mutation] — that's
    the {b abstract} record (target artifact + kind + manifest +
    detector); this module's [mutation] is the {b concrete}
    variant (how to actually mutate a file / SONAME). Two
    orthogonal layers of the same idea. *)

(** Concrete mutation applied to a project's world before the
    canary graph runs.

    - [Patch] applies a unified diff sourced from a per-project
      patches directory (tiny: [scenarios/patches/<file>]). The
      diff can touch any file (C source, OCaml source, header,
      Python module) — the harness re-runs its full build
      regardless, so no rebuild hint is needed.
    - [Soname_bump] renames a shared object + rewrites its
      SONAME via patchelf. Binary-level mutation — applies to
      the built artifact, not the source.

    Positive-coverage scenarios carry [None] on the wrapping
    [tiny_recipe.mutation] field — no mutation, base build.

    Future direction (per user 2026-07-09): a third variant
    like [Binutil { operation; args }] for other binary
    mutations (strip, patchelf --set-rpath, objcopy exports
    tweaks) that model real-world binary-level breakage. *)
type mutation =
  | Patch of { patch_file : string }
  | Soname_bump of { from_so : string; to_so : string }

(** Unified patch constructor. [name] resolves to
    [<name>.patch] under the per-project patches dir. Prior
    [c_patch] and [ml_patch] wrappers were dropped 2026-07-09
    — the distinction was purely descriptive (both wrote the
    same [Patch]; the [rebuild_target] field was never read). *)
let patch name = Some (Patch { patch_file = name ^ ".patch" })

(* ================================================================ *)
(* {1 Tool wrappers}                                                  *)
(*                                                                    *)
(* Return shell commands that a harness can execute. Application-     *)
(* logic-free: no [Sys.command] calls, no filesystem checks. Callers  *)
(* run the strings via their own runner and handle errors as they     *)
(* prefer. Parallel to how [canary_artifact_native] etc. provide      *)
(* inspection commands.                                                *)
(* ================================================================ *)

(** Shell command to apply a unified diff at [~sandbox_dir]. The
    patch file lives at [~patches_dir]/[~patch_file] (both should
    be absolute or relative to the caller's cwd). Assumes GNU
    [patch] and [-p1] stripping. *)
let apply_patch_cmd ~sandbox_dir ~patches_dir ~patch_file : string =
  Printf.sprintf
    "cd '%s' && patch -p1 < '%s/%s' > /dev/null"
    sandbox_dir patches_dir patch_file

(** Shell command sequence to apply a SONAME bump to a shared
    library sitting at [~lib_dir]/[~old_full_name].

    - Renames the file from [~old_full_name] to [~new_full_name].
    - Drops the old MAJOR symlink ([~old_major_name]) and the
      generic ([~generic_name]) symlink.
    - Recreates the MAJOR symlink ([~new_major_name]) pointing at
      the new file, and the generic symlink pointing at the new
      MAJOR.
    - Rewrites the embedded SONAME with [patchelf --set-soname]
      (falls back cleanly if patchelf isn't installed).

    Naming convention (SONAME chain):
    - full_name   = libX.so.MAJOR.MINOR — the actual file
    - major_name  = libX.so.MAJOR       — MAJOR symlink → full
    - generic_name = libX.so             — top symlink → MAJOR

    Both file names and the caller's [~lib_dir] are placed verbatim
    into the commands. *)
let apply_soname_bump_cmds
    ~lib_dir
    ~old_full_name
    ~old_major_name
    ~new_full_name
    ~new_major_name
    ~generic_name : string list =
  [
    Printf.sprintf "mv '%s/%s' '%s/%s'"
      lib_dir old_full_name lib_dir new_full_name;
    Printf.sprintf "rm -f '%s/%s' '%s/%s'"
      lib_dir generic_name lib_dir old_major_name;
    Printf.sprintf "ln -sf '%s' '%s/%s'"
      new_full_name lib_dir new_major_name;
    Printf.sprintf "ln -sf '%s' '%s/%s'"
      new_major_name lib_dir generic_name;
    Printf.sprintf "patchelf --set-soname '%s' '%s/%s' 2>/dev/null || true"
      new_major_name lib_dir new_full_name;
  ]

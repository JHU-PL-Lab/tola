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

(** What the harness must rebuild after applying a [Patch].
    Tiny-flavoured today — source patches under [c/] need the
    native C library rebuilt before probes run; patches to
    binding source files don't (canary rebuilds the binding
    itself as part of its own action graph). *)
type rebuild_target =
  | Rebuild_native_c
  | Rebuild_none

(** Concrete mutation applied to a project's world before the
    canary graph runs.

    - [Patch] applies a unified diff sourced from a per-project
      patches directory (tiny: [scenarios/patches/<file>]).
    - [Soname_bump] renames a shared object + rewrites its
      SONAME via patchelf (or byte surgery on distros without
      patchelf).

    Positive-coverage scenarios carry [None] on the wrapping
    [tiny_recipe.mutation] field — no mutation, base build. *)
type mutation =
  | Patch of { patch_file : string; rebuild : rebuild_target }
  | Soname_bump of { from_so : string; to_so : string }

(** Constructor for a C-side patch (rebuilds the native lib). *)
let c_patch name =
  Some (Patch { patch_file = name ^ ".patch"; rebuild = Rebuild_native_c })

(** Constructor for an OCaml-side patch (no native rebuild
    needed — canary rebuilds the binding). *)
let ml_patch name =
  Some (Patch { patch_file = name ^ ".patch"; rebuild = Rebuild_none })

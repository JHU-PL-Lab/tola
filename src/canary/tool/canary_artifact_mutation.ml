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

    Unmutated witnesses (SSOT §4.1) carry [None] on the wrapping
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

(* ================================================================ *)
(* {1 Surface delta}                                                 *)
(*                                                                    *)
(* Diff between "baseline" and "mutated" inspector JSONs. Project-    *)
(* agnostic JSON comparison — moved from [canary_tiny_workspace.ml]   *)
(* 2026-07-09. Used by the harness after a mutation to compute what   *)
(* actually changed at the surface level, and by tests to assert on   *)
(* the shape of an observed change.                                   *)
(*                                                                    *)
(* The JSON shape it recognises is the [inspect_*.py] output family:  *)
(* an [Assoc] with fields [symbols] / [requires] / [vals] / [attrs] / *)
(* [modules] (each a [`List] of strings), plus optional [elf.soname]  *)
(* and [elf.needed].                                                   *)
(* ================================================================ *)

let string_set_of_json = function
  | `List xs ->
    Base.List.filter_map xs
      ~f:(function `String s -> Some s | _ -> None)
    |> Base.Set.of_list (module Base.String)
  | _ -> Base.Set.empty (module Base.String)

let sorted_json_list_of_set s =
  `List (Base.Set.to_list s |> Base.List.map ~f:(fun x -> `String x))

let field_diff (b : Yojson.Basic.t) (p : Yojson.Basic.t) field
    : (string * Yojson.Basic.t) option =
  let open Base in
  let b_field =
    match b with `Assoc a -> List.Assoc.find a field ~equal:String.equal | _ -> None
  in
  let p_field =
    match p with `Assoc a -> List.Assoc.find a field ~equal:String.equal | _ -> None
  in
  match b_field, p_field with
  | None, None -> None
  | _ ->
    let b_set = Option.value_map b_field ~default:(Set.empty (module String))
                  ~f:string_set_of_json in
    let p_set = Option.value_map p_field ~default:(Set.empty (module String))
                  ~f:string_set_of_json in
    if Set.equal b_set p_set then None
    else
      let added   = Set.diff p_set b_set in
      let removed = Set.diff b_set p_set in
      Some (field,
            `Assoc [ "added",   sorted_json_list_of_set added;
                     "removed", sorted_json_list_of_set removed ])

let elf_of (j : Yojson.Basic.t) : Yojson.Basic.t =
  let open Base in
  match j with
  | `Assoc a ->
    (match List.Assoc.find a "elf" ~equal:String.equal with
     | Some v -> v | None -> `Assoc [])
  | _ -> `Assoc []

let string_or_null = function `String s -> Some s | `Null -> None | _ -> None

let soname_of (j : Yojson.Basic.t) : string option =
  let open Base in
  match elf_of j with
  | `Assoc a ->
    (match List.Assoc.find a "soname" ~equal:String.equal with
     | Some v -> string_or_null v | None -> None)
  | _ -> None

(** Compute the surface delta between baseline and mutated
    inspector JSONs. Returns [None] when both sides agree on
    every recognised field, [Some] with a summary otherwise.

    Fields compared as string sets: [symbols], [requires],
    [vals], [attrs], [modules]. Special cases: [elf.soname]
    (before/after) and [elf.needed] (added/removed). *)
let surface_delta
      (baseline : Yojson.Basic.t option)
      (mutated : Yojson.Basic.t option)
    : Yojson.Basic.t option =
  let open Base in
  match baseline, mutated with
  | None, None -> Some (`Assoc [ "status", `String "both_absent" ])
  | None, Some p ->
    Some (`Assoc [ "status", `String "baseline_absent"; "mutated", p ])
  | Some _, None ->
    Some (`Assoc [ "status", `String "mutated_absent" ])
  | Some b, Some p ->
    let field_deltas =
      List.filter_map ["symbols"; "requires"; "vals"; "attrs"; "modules"]
        ~f:(fun f -> field_diff b p f)
    in
    let elf_b = elf_of b and elf_p = elf_of p in
    let soname_delta =
      let bs = soname_of b and ps = soname_of p in
      if Option.equal String.equal bs ps then None
      else
        let opt_to_json = function
          | Some s -> `String s | None -> `Null in
        Some ("soname",
              `Assoc [ "baseline",  opt_to_json bs;
                       "mutated", opt_to_json ps ])
    in
    let needed_delta = field_diff elf_b elf_p "needed" in
    let all = field_deltas
              @ Option.to_list soname_delta
              @ Option.to_list needed_delta in
    match all with [] -> None | xs -> Some (`Assoc xs)

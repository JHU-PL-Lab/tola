(** Per-artifact mutation types + tool wrappers.

    Mirrors the inspection layer symmetry: [canary_artifact_source] /
    [_native] / [_lang] each own inspection wrappers for their
    artifact; here each per-artifact submodule ({!Source}, {!Native},
    {!Binding}) owns the {b mutations} that can apply to that
    artifact — a type enumerating them, constructors that name their
    intent, and an [apply_cmds] shell-command builder.

    Framing (per user 2026-07-20): "mutation is just an artifact-
    flavored fact — from an artifact-centric perspective, it's
    another artifact." The per-artifact type makes that framing
    structural. The top-level {!mutation} union is a thin sum for
    callers that need a single type (scenario.origin's Mutation
    payload).

    Not to be confused with [Canary_scenario.mutation] — that's
    the {b abstract} record (target artifact + kind + manifest +
    detector). This module's [mutation] is the {b concrete}
    variant (how to actually mutate a file / SONAME). Two
    orthogonal layers of the same idea. *)

open Base

(* ================================================================ *)
(* {1 Portable in-place editing}                                     *)
(*                                                                    *)
(* Every textual mutation below used to be [sed -i -E]. That is GNU   *)
(* form, and on BSD/macOS sed it fails in the WORST possible way —    *)
(* measured 2026-08-26, not inferred:                                 *)
(*                                                                    *)
(*   1. [-i] takes the backup SUFFIX as its argument there, so [-i    *)
(*      -E] means "back up to <file>-E" and the [-E] never reaches    *)
(*      the parser: the pattern is then read as BASIC regex, where    *)
(*      [(val|external|let)] is a literal and the alternation never   *)
(*      matches;                                                      *)
(*   2. [\b] is a GNU extension with no BSD equivalent, so the        *)
(*      word-boundary rename silently matches nothing;                *)
(*   3. sed EXITS 0 through both. The mutation is a no-op, the step   *)
(*      records success, and a bad-artifact scenario quietly becomes  *)
(*      a good one — a false PASS on the very cell that exists to     *)
(*      produce a failure. It also litters a [<file>-E] backup that   *)
(*      the [diff -r] regress oracle then reports as an extra file.   *)
(*                                                                    *)
(* [perl -i] is the one in-place editor whose FLAGS and REGEX DIALECT *)
(* are identical on both platforms (perl owns both, rather than       *)
(* deferring to the OS): [-i] with no suffix leaves no backup, [\b]   *)
(* and POSIX classes both work, and [...] is sed's inclusive range    *)
(* with sed's "never end on the start line" rule. perl is present by  *)
(* default on macOS and is an Ubuntu essential, so this adds no       *)
(* dependency the framework did not already have.                     *)
(*                                                                    *)
(* The patch files under canary/examples/tiny/scenarios/patches/ stay *)
(* the ORACLE: [mut.regress.*] applies each patch and each mutation   *)
(* to clean trees and [diff -r]s them, so any dialect drift between   *)
(* the two forms is a test failure, not a silent divergence.          *)
(* ================================================================ *)

(** In-place substitution ([perl -pe]): the whole file is rewritten,
    each line passed through [script]. *)
let perl_subst ~(script : string) ~(path : string) : string =
  Printf.sprintf "perl -i -pe '%s' '%s'" script path

(** In-place line FILTER ([perl -ne]): only what [script] prints
    survives. The sed idiom [/re/d] becomes [print unless /re/]. *)
let perl_filter ~(script : string) ~(path : string) : string =
  Printf.sprintf "perl -i -ne '%s' '%s'" script path

(* ================================================================ *)
(* {1 Source-artifact mutations}                                     *)
(* ================================================================ *)

module Source = struct
  (** Mutations that apply to source artifacts (C source, headers,
      version scripts). Enumerated per shape:

      - [Rename_c_symbol] — replace one C identifier throughout a
        file. Uses [sed] with word-boundary anchors. Reference case:
        tiny [symbol_missing] renames [tiny_sum] → [tiny_total] in
        [c/src/tiny.c].
      - [Rename_version_tag] — replace a version-script tag name
        (e.g. [TINY_1.0] → [TINY_2.0]). Reference case: tiny
        [symbol_version_floor] on [c/tiny.map].

      Missing (deferred, per user 2026-07-20 principle "per-artifact
      ops make missing-ness visible"):
      - [Drop_c_symbol] — remove a C function definition (multi-line,
        needs brace-matching). No current tiny reference; add when a
        cell needs it. *)
  type t =
    | Rename_c_symbol of { file : string; from_ : string; to_ : string }
    | Rename_version_tag of { file : string; from_ : string; to_ : string }

  let rename_c_symbol ~file ~from_ ~to_ =
    Rename_c_symbol { file; from_; to_ }

  let rename_version_tag ~file ~from_ ~to_ =
    Rename_version_tag { file; from_; to_ }

  (** Shell commands to apply this mutation to a sandbox rooted at
      [~sandbox]. Returns a list; callers compose with [&&] or run
      one-by-one and check each rc. *)
  let apply_cmds ~sandbox = function
    | Rename_c_symbol { file; from_; to_ } ->
        (* Word-boundary rename. [\b] is why this cannot be sed: it is
           a GNU extension, and BSD sed matches nothing while exiting
           0 (see the portability note at the top). *)
        [ perl_subst
            ~script:(Printf.sprintf "s/\\b%s\\b/%s/g" from_ to_)
            ~path:(Printf.sprintf "%s/%s" sandbox file) ]
    | Rename_version_tag { file; from_; to_ } ->
        (* Version tag rename: match at start-of-line followed by
           whitespace + brace. Distinct enough from C-symbol rename
           to warrant its own primitive. The POSIX class is kept
           verbatim from the sed form — perl understands it, so the
           pattern did not have to be re-derived. *)
        [ perl_subst
            ~script:(Printf.sprintf "s/^%s[[:space:]]*\\{/%s {/" from_ to_)
            ~path:(Printf.sprintf "%s/%s" sandbox file) ]
end

(* ================================================================ *)
(* {1 Native-artifact mutations}                                     *)
(* ================================================================ *)

(** Rewrite a built shared library's own recorded name — the thing a
    consumer records at link time and dyld/ld.so resolves at load time.

    Two tools for one concept: ELF calls it the SONAME and [patchelf]
    sets it; Mach-O calls it the install_name and [install_name_tool -id]
    sets it, conventionally with an [@rpath/] prefix so the consumer's
    rpath decides where it is found.

    [name] is the caller's, and tiny's are still ELF-shaped
    ([libtiny.so.2] rather than [libtiny.2.dylib]) — see
    {!Canary_basic.shared_lib_name} for the two conventions and
    doc/canary/project/issues.md for tiny's remaining Mach-O port. This
    function makes the TOOL right; the NAME becomes right when tiny
    stops spelling its libraries for one platform. *)
let set_recorded_name_cmd ~(name : string) ~(lib : string) : string =
  match Canary_basic.detect_distro () with
  | Canary_store.MacOS_local ->
      Printf.sprintf "install_name_tool -id '@rpath/%s' '%s' 2>/dev/null || true"
        name lib
  | Canary_store.Wsl ->
      Printf.sprintf "patchelf --set-soname '%s' '%s' 2>/dev/null || true"
        name lib

module Native = struct
  (** Mutations that apply to native library artifacts (.so /
      .dylib). Binary-level — operate on the built lib, not source.

      - [Soname_bump] — rename a shared object + rewrite the name it
        records for itself ({!set_recorded_name_cmd}: SONAME via
        [patchelf] on ELF, install_name via [install_name_tool] on
        Mach-O). Reference case: tiny [abi_soname_bump] bumps
        [libtiny.so.1.0] → [libtiny.so.2.0]. Also renames the
        corresponding MAJOR symlink and rewrites the generic symlink. *)
  type t = Soname_bump of { from_so : string; to_so : string }

  let soname_bump ~from_so ~to_so = Soname_bump { from_so; to_so }

  (* Strip a trailing ".N" (all-digit) segment; used to derive MAJOR
     from FULL name (libX.so.1.0 → libX.so.1). Matches the existing
     tiny convention. *)
  let strip_trailing_minor s =
    let parts = String.split ~on:'.' s in
    match List.rev parts with
    | last :: rest when String.for_all last ~f:Char.is_digit
                        && not (String.is_empty last) ->
        String.concat ~sep:"." (List.rev rest)
    | _ -> s

  (* Derive the generic symlink name from a FULL library filename:
     libX.so.MAJOR.MINOR → libX.so. Strip trailing digits repeatedly. *)
  let generic_name_of full =
    let rec strip s =
      let s' = strip_trailing_minor s in
      if String.equal s s' then s else strip s'
    in
    strip full

  (** Shell commands to apply this mutation to a sandbox rooted at
      [~sandbox]. The lib is expected at [~lib_dir] relative to
      [~sandbox]; tiny uses ["c/build"] by convention. *)
  let apply_cmds ~sandbox ?(lib_dir = "c/build") = function
    | Soname_bump { from_so; to_so } ->
        let old_full = from_so in
        let new_full = to_so in
        let old_major = strip_trailing_minor from_so in
        let new_major = strip_trailing_minor to_so in
        let generic = generic_name_of from_so in
        let lib_path = sandbox ^ "/" ^ lib_dir in
        [
          Printf.sprintf "mv '%s/%s' '%s/%s'"
            lib_path old_full lib_path new_full;
          Printf.sprintf "rm -f '%s/%s' '%s/%s'"
            lib_path generic lib_path old_major;
          Printf.sprintf "ln -sf '%s' '%s/%s'"
            new_full lib_path new_major;
          Printf.sprintf "ln -sf '%s' '%s/%s'"
            new_major lib_path generic;
          set_recorded_name_cmd ~name:new_major
            ~lib:(Printf.sprintf "%s/%s" lib_path new_full);
        ]
end

(* ================================================================ *)
(* {1 Binding-artifact mutations}                                    *)
(* ================================================================ *)

module Binding = struct
  (** Mutations that apply to binding artifacts (OCaml .mli / .ml,
      Python .py). Currently:

      - [Drop_ocaml_val] — remove a [val <name> : ...] or
        [external <name> : ...] declaration from a .mli/.ml file.
        Line-based; the declaration terminates at end-of-line or
        the next [val/external/let] keyword. Reference case: tiny
        [api_complete] drops [val sum] from [ocaml/tiny.mli].
      - [Drop_python_attr] — remove a top-level [def <name>(...):]
        block from a Python file, along with the immediately
        following blank line. Range-based sed: matches from a line
        beginning [def <name>(] through the next blank line, deletes
        them. Reference case: tiny [api_complete_python] drops
        [def sum] from [python_cext/tiny_cext/__init__.py] —
        byte-identical to the existing patch. Limitations: assumes
        blank-line-separated defs; does not handle decorators above
        the def; does not remove [Assign]/[AnnAssign]/[ClassDef]
        attributes (only [FunctionDef]). Adequate for tiny; upgrade
        to an [ast]-based transform if a project needs the fuller
        vocabulary. *)
  type t =
    | Drop_ocaml_val of { file : string; name : string }
    | Drop_python_attr of { file : string; name : string }

  let drop_ocaml_val ~file ~name = Drop_ocaml_val { file; name }
  let drop_python_attr ~file ~name = Drop_python_attr { file; name }

  let apply_cmds ~sandbox = function
    | Drop_ocaml_val { file; name } ->
        (* Match a line starting with `val <name>`, `external <name>`,
           or `let <name>` (optionally with leading whitespace),
           optionally followed by continuation lines that don't start
           with `val`, `external`, `let`, or the file's structural
           keywords. Simpler: single-line for now — matches the
           existing api_complete.patch shape. *)
        [ perl_filter
            ~script:
              (Printf.sprintf
                 "print unless \
                  /^[[:space:]]*(val|external|let)[[:space:]]+%s([[:space:]]|:|=)/"
                 name)
            ~path:(Printf.sprintf "%s/%s" sandbox file) ]
    | Drop_python_attr { file; name } ->
        (* Delete from `def <name>(` through the first blank line.
           Matches the api_complete_python.patch shape byte-for-byte
           on the tiny fixture. Range end pattern is a whitespace-only
           line, so trailing-space blank lines match too.

           [...] not [..]: perl's three-dot range, like sed's [/a/,/b/],
           refuses to end on the line that STARTED it. (No tiny fixture
           separates them — a `def` line is never blank — but the two
           operators are not interchangeable and the sed semantics are
           what the patch oracle encodes.) *)
        [ perl_filter
            ~script:
              (Printf.sprintf
                 "print unless /^def[[:space:]]+%s[[:space:]]*\\(/ ... \
                  /^[[:space:]]*$/"
                 name)
            ~path:(Printf.sprintf "%s/%s" sandbox file) ]
end

(* ================================================================ *)
(* {1 Top-level mutation union}                                      *)
(* ================================================================ *)

(** A mutation on any-flavor artifact, plus the [Patch] escape
    hatch for freeform edits. Used where callers need a
    homogeneous type (scenario.origin's Mutation payload).

    - [Of_source] / [Of_native] / [Of_binding] — parametric,
      structured mutations. Constructor list is the artifact's
      exhaustive vocabulary.
    - [Patch] — cross-cutting: a unified diff can touch any file
      across any artifact kind. Kept as an escape hatch until (a)
      the parametric vocabulary covers a shape, or (b) the change
      is intentionally freeform (e.g. behavior_silent). *)
type mutation =
  | Of_source of Source.t
  | Of_native of Native.t
  | Of_binding of Binding.t
  | Patch of { patch_file : string }

(** Unified patch constructor. [name] resolves to
    [<name>.patch] under the per-project patches dir. Kept for
    tiny's existing recipe style; a naked [Patch { patch_file }]
    works too. *)
let patch name = Some (Patch { patch_file = name ^ ".patch" })

(** Dispatch [apply_cmds] to the per-artifact module. The [Patch]
    case needs a [~patches_dir] resolution — callers who pass
    [Patch] mutations should invoke [apply_patch_cmd] below
    directly, since it needs a [~patches_dir] argument the union
    dispatch doesn't carry. *)
let apply_cmds ~sandbox = function
  | Of_source m -> Source.apply_cmds ~sandbox m
  | Of_native m -> Native.apply_cmds ~sandbox m
  | Of_binding m -> Binding.apply_cmds ~sandbox m
  | Patch _ ->
      (* Patch application needs ~patches_dir; the union dispatch
         doesn't carry it. Callers should match Patch explicitly
         and call [apply_patch_cmd] with the resolution.
         Returning [] here would swallow a Patch silently; prefer
         a helpful failure. *)
      Stdlib.failwith
        "apply_cmds: Patch case needs ~patches_dir; call \
         apply_patch_cmd directly"

(* ================================================================ *)
(* {1 Legacy tool wrappers}                                          *)
(*                                                                    *)
(* Predate the per-artifact split (2026-07-20). Kept public because   *)
(* [canary_tiny_workspace.ml]'s [apply_patch] / [apply_soname_bump]   *)
(* wrappers still call them directly (they take from_so/to_so as     *)
(* strings, not through the variant). Future refactor may migrate    *)
(* those wrappers to call [Source.apply_cmds] / [Native.apply_cmds]   *)
(* and retire these; not part of Phase 1.                             *)
(* ================================================================ *)

(** Shell command to apply a unified diff at [~sandbox_dir]. The
    patch file lives at [~patches_dir]/[~patch_file]. *)
let apply_patch_cmd ~sandbox_dir ~patches_dir ~patch_file : string =
  Printf.sprintf
    "cd '%s' && patch -p1 < '%s/%s' > /dev/null"
    sandbox_dir patches_dir patch_file

(** Shell command sequence to apply a SONAME bump. Callers pass
    all five names explicitly. See {!Native.apply_cmds} for the
    variant-driven version that derives major names automatically. *)
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
    set_recorded_name_cmd ~name:new_major_name
      ~lib:(Printf.sprintf "%s/%s" lib_dir new_full_name);
  ]

(* ================================================================ *)
(* {1 Surface delta}                                                 *)
(*                                                                    *)
(* Diff between "baseline" and "mutated" inspector JSONs. Project-    *)
(* agnostic; unchanged by the per-artifact refactor.                   *)
(* ================================================================ *)

let string_set_of_json = function
  | `List xs ->
    List.filter_map xs
      ~f:(function `String s -> Some s | _ -> None)
    |> Set.of_list (module String)
  | _ -> Set.empty (module String)

let sorted_json_list_of_set s =
  `List (Set.to_list s |> List.map ~f:(fun x -> `String x))

let field_diff (b : Yojson.Basic.t) (p : Yojson.Basic.t) field
    : (string * Yojson.Basic.t) option =
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
  match j with
  | `Assoc a ->
    (match List.Assoc.find a "elf" ~equal:String.equal with
     | Some v -> v | None -> `Assoc [])
  | _ -> `Assoc []

let string_or_null = function `String s -> Some s | `Null -> None | _ -> None

let soname_of (j : Yojson.Basic.t) : string option =
  match elf_of j with
  | `Assoc a ->
    (match List.Assoc.find a "soname" ~equal:String.equal with
     | Some v -> string_or_null v | None -> None)
  | _ -> None

let surface_delta
      (baseline : Yojson.Basic.t option)
      (mutated : Yojson.Basic.t option)
    : Yojson.Basic.t option =
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

open Base

(* ── Output Layout v3 helpers ──
   Centralises three derivations that must stay in sync:
     step_dir_of_tag : string → string   action-first directory path
     filename        : base, ext, variant_key → string
     variant_file    : existing filename → variant-keyed filename

   All three obey the same convention:
     - Binding tags use action-first grouping: "build_binding/ocaml"
     - variant_key="" → unchanged names (backward-compat for single-variant)
     - variant_key="X" → "base_X.ext" suffix *)

(* Map a step tag to its filesystem directory path relative to project_dir.
   Binding tags ("build_binding_ocaml", "probe_binding_python_pip", …) are
   grouped action-first:  verb_binding/<rest>  so that all variants of the
   same binding action land in a single parent directory.
   Non-binding tags are their own directory (unchanged). *)
let step_dir_of_tag tag =
  let verbs = [ "build"; "probe"; "fetch"; "pack" ] in
  match
    List.find_map verbs ~f:(fun verb ->
        let prefix = verb ^ "_binding_" in
        match String.chop_prefix tag ~prefix with
        | Some rest -> Some (verb ^ "_binding/" ^ rest)
        | None -> None)
  with
  | Some d -> d
  | None -> tag

(* Variant-qualified filename.
   variant_key = ""  → "base.ext"       (single-variant: unchanged)
   variant_key = "19" → "base_19.ext"   (multi-variant: type-first, version last) *)
let filename ~variant_key ~base ~ext =
  if String.is_empty variant_key then base ^ "." ^ ext
  else base ^ "_" ^ variant_key ^ "." ^ ext

(* Apply variant_key to an already-formed "base.ext" filename.
   Useful when the base name is not split (e.g., "probe.log" → "probe_19.log"). *)
let variant_file ~variant_key fname =
  if String.is_empty variant_key then fname
  else
    match String.rsplit2 fname ~on:'.' with
    | Some (base, ext) -> base ^ "_" ^ variant_key ^ "." ^ ext
    | None -> fname ^ "_" ^ variant_key

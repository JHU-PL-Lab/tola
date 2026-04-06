open Base

(* Artifact checking: knows HOW to verify each artifact type.
   Project specs provide WHAT to check (paths, prefixes).

   Two levels:
   - Existence checks (bool): fast, for use in check_post
   - Shell probe commands (string): write logs to output_dir, for probe steps
   - Inline symbol check (OCaml): deeper check, callable from check_post or reporter *)

(* ── Platform detection ── *)

let platform =
  let ic = Unix.open_process_in "uname -s 2>/dev/null" in
  let s = try String.strip (Stdlib.input_line ic) with End_of_file -> "" in
  ignore (Unix.close_process_in ic);
  s

let is_macos = String.equal platform "Darwin"

(* ── Artifact kind predicates ── *)

let is_native_lib path =
  let b = Stdlib.Filename.basename path in
  String.is_suffix path ~suffix:".so"
  || String.is_suffix path ~suffix:".dylib"
  || String.is_suffix path ~suffix:".a"
  || String.is_substring b ~substring:".so."
  || String.is_substring b ~substring:".dylib."

let is_ocaml_archive path =
  String.is_suffix path ~suffix:".cmxa"
  || String.is_suffix path ~suffix:".cma"

(* ── Existence checks (bool, for check_post) ── *)

let exists_native_lib path =
  Stdlib.Sys.file_exists path && is_native_lib path

(* macOS: .dylib fallback when .so is requested *)
let exists_native_lib_or_dylib path =
  Stdlib.Sys.file_exists path
  || Stdlib.Sys.file_exists
       (Stdlib.Filename.remove_extension path ^ ".dylib")

let exists_ocaml_archive path =
  Stdlib.Sys.file_exists path && is_ocaml_archive path

(* Companion C stub archive: z3ml.cmxa → libz3ml.a (contains C FFI symbols).
   `ocamlmklib` names its outputs lib<name>.a and dll<name>.so by convention.
   This naming is NOT universal — it depends on how the binding was built.
   TODO: factor this into the OCaml toolchain layer (like canary_basic_opam.ml
   for PM ops), so each project declares its stub archive path rather than
   relying on this derived default. For now, works for z3ml. *)
let cmxa_stub_archive path =
  let dir = Stdlib.Filename.dirname path in
  let base = Stdlib.Filename.basename path in
  let name = Stdlib.Filename.remove_extension base in
  dir ^ "/lib" ^ name ^ ".a"

let python_importable pkg =
  Stdlib.Sys.command
    (Printf.sprintf "python3 -c 'import %s' 2>/dev/null" pkg)
  = 0

(* ── nm-based symbol inspection ── *)

let nm_cmd path =
  if is_macos then Printf.sprintf "nm -g '%s' 2>/dev/null" path
  else if is_native_lib path then
    Printf.sprintf "nm -D '%s' 2>/dev/null" path
  else Printf.sprintf "nm '%s' 2>/dev/null" path

let run_nm path =
  let ic = Unix.open_process_in (nm_cmd path) in
  let lines = ref [] in
  (try
     while true do
       lines := Stdlib.input_line ic :: !lines
     done
   with End_of_file -> ());
  ignore (Unix.close_process_in ic);
  List.rev !lines

(* Defined symbols (kind != U) with given prefix *)
let symbols_defined ~prefix lines =
  List.filter_map lines ~f:(fun line ->
      let parts =
        String.split line ~on:' '
        |> List.filter ~f:(fun s -> not (String.is_empty s))
      in
      match parts with
      | [ _; kind; sym ] | [ kind; sym ]
        when String.length kind = 1
             && Char.( <> ) (Char.uppercase kind.[0]) 'U'
             && String.is_prefix sym ~prefix ->
          Some sym
      | _ -> None)

(* Undefined symbols (kind = U) with given prefix *)
let symbols_undefined ~prefix lines =
  List.filter_map lines ~f:(fun line ->
      let parts =
        String.split line ~on:' '
        |> List.filter ~f:(fun s -> not (String.is_empty s))
      in
      match parts with
      | [ _; "U"; sym ] | [ "U"; sym ] when String.is_prefix sym ~prefix ->
          Some sym
      | _ -> None)

type symbol_check_result = {
  n_provided : int;
  n_required : int;
  missing : string list;
}

(* Cross-check: symbols required by required_libs must be provided by provided_lib.
   Equivalent to canary/scripts/assert_binary_symbols.py but callable from OCaml. *)
let check_symbols ~provided_lib ~required_libs ~prefix =
  let provided =
    run_nm provided_lib
    |> symbols_defined ~prefix
    |> List.dedup_and_sort ~compare:String.compare
    |> Hash_set.of_list (module String)
  in
  let required =
    List.concat_map required_libs ~f:(fun lib ->
        run_nm lib |> symbols_undefined ~prefix)
    |> List.dedup_and_sort ~compare:String.compare
  in
  let missing =
    List.filter required ~f:(fun s -> not (Hash_set.mem provided s))
  in
  { n_provided = Hash_set.length provided;
    n_required = List.length required;
    missing
  }

(* ── Shell probe commands (write to output_dir, for probe steps) ── *)

(* Sanity probe: count symbols with prefix exported by a native lib.
   Writes probe.log; exits nonzero if the count is zero.
   Use to verify the lib compiled and exports the expected API surface. *)
let native_lib_probe_cmd ~lib ~prefix ~output_dir =
  let nm_flag = if is_macos then "-g" else "-D" in
  [%string
    {|COUNT=$(nm %{nm_flag} "%{lib}" 2>/dev/null | grep -v ' U ' | grep -c '%{prefix}' || echo 0)
printf '%{prefix} symbols exported: %s\n' "$COUNT" | tee %{output_dir}/probe.log
test "$COUNT" -gt 0|}]

(* Symbol compatibility probe via assert_binary_symbols.py.
   Writes symbols.log; exits nonzero if symbols are missing. *)
let native_symbol_check_cmd ~provided_lib ~required_libs ~prefix ~output_dir =
  let script = "canary/scripts/assert_binary_symbols.py" in
  let req_args =
    List.map required_libs ~f:(fun l -> "--required-lib " ^ l)
    |> String.concat ~sep:" "
  in
  [%string
    "python3 %{script} --provided-lib %{provided_lib} %{req_args} \
     --symbol-prefix %{prefix} 2>&1 | tee %{output_dir}/symbols.log && \
     grep -q 'OK:' %{output_dir}/symbols.log"]

(* OCaml archive probe via ocamlobjinfo. Writes archive.log. *)
let ocaml_archive_info_cmd ~archive ~output_dir =
  [%string "ocamlobjinfo %{archive} 2>&1 | tee %{output_dir}/archive.log"]

(* Inspect all OCaml archives (.cmxa/.cma) in an opam-installed package.
   Discovers the package dir via `ocamlfind query`, runs ocamlobjinfo on
   each archive found. Writes archive.log. *)
let opam_pkg_inspect_cmd ~pkg ~output_dir =
  [%string
    {|eval $(opam env)
PKG_DIR=$(ocamlfind query '%{pkg}' 2>/dev/null)
test -n "$PKG_DIR"
for f in "$PKG_DIR"/*.cmxa "$PKG_DIR"/*.cma; do
  [ -f "$f" ] && printf '\n=== %s ===\n' "$f" && ocamlobjinfo "$f"
done 2>&1 | tee %{output_dir}/archive.log|}]

(* Symbol compat check for an opam-installed binding vs a system native lib.
   Discovers stub archive via `ocamlfind query <pkg>` (looks for lib*.a),
   finds the system lib with `provided_lib_cmd` (a shell expression → path).
   Writes symbols.log; exits nonzero if symbols are missing.
   provided_lib_cmd example: "ls \"$(llvm-config --libdir)\"/libLLVM*.so | head -1" *)
let opam_pkg_symbol_check_cmd ~pkg ~provided_lib_cmd ~prefix ~output_dir =
  let script = "canary/scripts/assert_binary_symbols.py" in
  [%string
    {|eval $(opam env)
PKG_DIR=$(ocamlfind query '%{pkg}' 2>/dev/null)
test -n "$PKG_DIR"
STUB=$(ls "$PKG_DIR"/lib*.a 2>/dev/null | head -1)
test -n "$STUB"
PROVIDED=$(%{provided_lib_cmd})
test -n "$PROVIDED"
python3 %{script} --provided-lib "$PROVIDED" --required-lib "$STUB" \
  --symbol-prefix %{prefix} 2>&1 | tee %{output_dir}/symbols.log
grep -q 'OK:' %{output_dir}/symbols.log|}]

(* Python import probe. Writes import.log. *)
let python_import_cmd ~pkg ~output_dir =
  [%string
    "python3 -c 'import %{pkg}; print(\"%{pkg} ok\")' 2>&1 | \
     tee %{output_dir}/import.log"]

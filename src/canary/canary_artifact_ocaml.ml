open Base

(* OCaml archive artifact ops.
   Handles .cmxa / .cma formats. Uses ocamlobjinfo for archive inspection
   and ocamlfind query for opam-installed package discovery.

   NOTE: Richer inspectors already exist across the whole [src/binding/]
   directory (~1880 lines, called from [src/bin/example_sp.ml]). The most
   directly relevant are:
     - [src/binding/ocaml_files.ml]   — file classification via [Objinfo.extra]
     - [src/binding/ocamls.ml]        — proper OCaml archive inspection
     - [src/binding/shared_library.ml]— ldd-style linked-dep extraction
     - [src/binding/macho.ml]         — macOS Mach-O / dyld inspection
     - [src/binding/resolve.ml]       — Via_name / Via_value matching
     - [src/binding/canary.ml]        — old canary model (test case enumeration)
   All use native OCaml compiler/opam libraries, not shell. See CLAUDE.md
   "Known Gaps" for full table + migration priority. *)

(* ── Kind predicates & existence checks ── *)

let is_ocaml_archive path =
  String.is_suffix path ~suffix:".cmxa"
  || String.is_suffix path ~suffix:".cma"

let exists_ocaml_archive path =
  Stdlib.Sys.file_exists path && is_ocaml_archive path

(* Companion C stub archive: z3ml.cmxa → libz3ml.a (contains C FFI symbols).
   `ocamlmklib` names its outputs lib<name>.a and dll<name>.so by convention.
   This naming is NOT universal — it depends on how the binding was built.
   TODO: factor this into the OCaml toolchain layer (like canary_pm_opam.ml
   for PM ops), so each project declares its stub archive path rather than
   relying on this derived default. For now, works for z3ml. *)
let cmxa_stub_archive path =
  let dir = Stdlib.Filename.dirname path in
  let base = Stdlib.Filename.basename path in
  let name = Stdlib.Filename.remove_extension base in
  dir ^ "/lib" ^ name ^ ".a"

(* ── Shell probe commands ── *)

(* Emit compact archive summary as summary.json.
   Module-level only (ocamlobjinfo doesn't expose constructors);
   constructor-level drift is detected via compile probes.
   See doc/canary/design/artifact_summary.md. *)
let summary_cmd ~archive ?(watchlist = []) ~output_dir () =
  let script = "canary/scripts/summarize_ocaml.py" in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  [%string
    {|ocamlobjinfo '%{archive}' 2>/dev/null \
  | python3 %{script} --path '%{archive}' --watchlist '%{watchlist_csv}' \
  > %{output_dir}/summary.json|}]

(* Emit summary for an opam-installed OCaml package: inspects all its
   .cmxa/.cma archives via ocamlfind query + ocamlobjinfo, merged into one
   summary.json with combined module list.
   NOTE: [~pkg] must be the *ocamlfind* package name, not the opam package
   name. These can differ: e.g., opam has llvm.19-shared / llvm.dev-shared
   variants, but the ocamlfind package they all install is just "llvm". *)
let summary_opam_pkg_cmd ~pkg ?(watchlist = []) ~output_dir () =
  let script = "canary/scripts/summarize_ocaml.py" in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  [%string
    {|eval $(opam env)
PKG_DIR=$(ocamlfind query '%{pkg}' 2>/dev/null)
test -n "$PKG_DIR"
{ for f in "$PKG_DIR"/*.cmxa "$PKG_DIR"/*.cma; do
    [ -f "$f" ] && ocamlobjinfo "$f"
  done
} | python3 %{script} --path '%{pkg}' --watchlist '%{watchlist_csv}' \
  > %{output_dir}/summary.json|}]

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

open Base

(* Language binding artifact ops — OCaml and Python.
   Both cover importable / linkable binding artifacts (as opposed to native
   system libs handled in canary_artifact_native.ml).

   OCaml NOTE: Richer inspectors exist in [src/binding/] (~1880 lines,
   called from [src/bin/example_sp.ml]). Most relevant:
     - [src/binding/ocaml_files.ml]   — file classification via [Objinfo.extra]
     - [src/binding/ocamls.ml]        — proper OCaml archive inspection
     - [src/binding/shared_library.ml]— ldd-style linked-dep extraction
     - [src/binding/macho.ml]         — macOS Mach-O / dyld inspection
     - [src/binding/resolve.ml]       — Via_name / Via_value matching
     - [src/binding/canary.ml]        — old canary model (test case enumeration)
   All use native OCaml compiler/opam libraries, not shell. See CLAUDE.md
   "Known Gaps" for full table + migration priority. *)

(* ── OCaml ── *)

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

(* Emit compact archive summary as summary.json.
   Module-level only (ocamlobjinfo doesn't expose constructors);
   constructor-level drift is detected via compile probes.
   See doc/canary/design/api_interface.md. *)
let summary_cmd ~archive ?(watchlist = []) ~output_dir ~variant_key () =
  let script = "canary/scripts/summarize_ocaml.py" in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  let out_file = Canary_step_key.filename ~variant_key ~base:"summary" ~ext:"json" in
  [%string
    {|ocamlobjinfo '%{archive}' 2>/dev/null \
  | python3 %{script} --path '%{archive}' --watchlist '%{watchlist_csv}' \
  > %{output_dir}/%{out_file}|}]

(* Emit summary for an opam-installed OCaml package: inspects all its
   .cmxa/.cma archives via ocamlfind query + ocamlobjinfo, merged into one
   summary.json with combined module list.
   NOTE: [~pkg] must be the *ocamlfind* package name, not the opam package
   name. These can differ: e.g., opam has llvm.19-shared / llvm.dev-shared
   variants, but the ocamlfind package they all install is just "llvm". *)
let summary_opam_pkg_cmd ~pkg ?(watchlist = []) ~output_dir ~variant_key () =
  let script = "canary/scripts/summarize_ocaml.py" in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  let out_file = Canary_step_key.filename ~variant_key ~base:"summary" ~ext:"json" in
  [%string
    {|eval $(opam env)
PKG_DIR=$(ocamlfind query '%{pkg}' 2>/dev/null)
test -n "$PKG_DIR"
{ for f in "$PKG_DIR"/*.cmxa "$PKG_DIR"/*.cma; do
    [ -f "$f" ] && ocamlobjinfo "$f"
  done
} | python3 %{script} --path '%{pkg}' --watchlist '%{watchlist_csv}' \
  > %{output_dir}/%{out_file}|}]

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

(* Source-level mli summary for an opam-installed OCaml binding.
   Discovers the package's .mli files via `ocamlfind query` and parses them
   with summarize_binding.py (grep-based, no compiler needed). Output JSON
   includes vals + constructors + module nesting (richer than ocamlobjinfo,
   which is module-level only).

   Use this when the binding ships .mli files in the install dir (LLVM does;
   z3 does too). When .mli files aren't installed, fall back to summary_opam_pkg_cmd. *)
let mli_summary_opam_pkg_cmd ~pkg ?(watchlist = []) ~output_dir ~variant_key () =
  let script = "canary/scripts/summarize_binding.py" in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  let out_file = Canary_step_key.filename ~variant_key ~base:"summary" ~ext:"json" in
  [%string
    {|eval $(opam env)
PKG_DIR=$(ocamlfind query '%{pkg}' 2>/dev/null)
test -n "$PKG_DIR"
python3 %{script} --kind mli --dir "$PKG_DIR" \
  --watchlist '%{watchlist_csv}' > %{output_dir}/%{out_file}|}]

(* C-stub summary: undefined symbols a binding requires from its native lib.
   Discovers the binding's stub archive (lib<name>.a) via `ocamlfind query`,
   runs `nm` to collect undefined symbols, optionally filtered by a prefix
   (e.g. Z3_, LLVM). Output JSON has the consumer-side symbol set — pair
   with summarize_native.py output (provider side) for check_compat.
   Default filename "stub_summary.json" so it can coexist with the OCaml-level
   "summary.json" in the same probe output directory. *)
let stub_summary_opam_pkg_cmd
    ~pkg ?(prefix = "") ?(watchlist = []) ~output_dir ~variant_key () =
  let script = "canary/scripts/summarize_binding.py" in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  (* v3 naming: "summary_stub" (type-first), variant-keyed → "summary_stub_19.json" *)
  let out_file = Canary_step_key.filename ~variant_key ~base:"summary_stub" ~ext:"json" in
  [%string
    {|eval $(opam env)
PKG_DIR=$(ocamlfind query '%{pkg}' 2>/dev/null)
test -n "$PKG_DIR"
STUB=$(ls "$PKG_DIR"/lib*.a 2>/dev/null | head -1)
test -n "$STUB"
python3 %{script} --kind stub --path "$STUB" \
  --prefix '%{prefix}' --watchlist '%{watchlist_csv}' \
  > %{output_dir}/%{out_file}|}]

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

(* ── Python ── *)

(* A "python artifact" is importable via `python3 -c 'import <pkg>'`.
   No filesystem path to check — the package may live in site-packages,
   a venv, or be installed globally. *)

let python_importable pkg =
  Stdlib.Sys.command
    (Printf.sprintf "python3 -c 'import %s' 2>/dev/null" pkg)
  = 0

(* Python import probe. Writes import.log.
   Output goes to file first, then cat — this preserves python's exit code.
   `| tee` would swallow the exit code (tee returning 0 even when python fails). *)
let python_import_cmd ~pkg ~output_dir =
  [%string
    "python3 -c 'import %{pkg}; print(\"%{pkg} ok\")' \
     > %{output_dir}/import.log 2>&1 && cat %{output_dir}/import.log"]

(* Emit compact Python package summary as summary.json via
   canary/scripts/summarize_python.py. Watchlist is a list of top-level
   attribute names; present/missing recorded in the JSON.
   See doc/canary/ops/python_binding_gotchas.md. *)
let python_summary_cmd ~pkg ?(watchlist = []) ~output_dir ~variant_key () =
  let script = "canary/scripts/summarize_python.py" in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  let out_file = Canary_step_key.filename ~variant_key ~base:"summary" ~ext:"json" in
  [%string
    "python3 %{script} --pkg '%{pkg}' --watchlist '%{watchlist_csv}' > %{output_dir}/%{out_file}"]

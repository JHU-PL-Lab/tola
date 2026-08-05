open Base

(** Language binding artifact ops — OCaml and Python.

    In surface-theory terms, this module drives the inspectors that
    extract the binding side's surfaces (s3 stub-facing through s5
    compiled) for both supported languages. Two scripts dispatched
    from here:

    - [inspect_binding.py]
      {ul
        {- [--kind mli] reads a [.mli] producing the {i s4 user_facing}
           JSON. Aliases: {i bo4 user_binding_ocaml.mli}.}
        {- [--kind stub] reads a stub archive's undefined refs producing
           the {i s5 compiled_binding.stub-a} JSON. Aliases: {i bo7
           compiled_binding_ocaml.stub-a}.}
      }
    - [inspect_ocaml.py] reads a [.cmxa] producing the {i s5
      compiled_binding_ocaml.cmxa} JSON via [ocamlobjinfo]. Aliases:
      {i bo6 compiled_binding_ocaml.cmxa}.
    - [inspect_python.py] reads a Python package's [dir()] producing the
      {i s4 user_facing} JSON. Aliases: {i bpe2 user_binding_cext.py}
      and {i bpc2 user_binding_ctypes.py}.

    Both languages cover importable / linkable binding artifacts (as
    opposed to native system libs handled in [canary_artifact_native.ml],
    which targets {i s2 native_lib} = {i n4}).

    OCaml NOTE: Richer inspectors exist in [src/binding/] (~1880 lines,
    called from [doc/_legacy_code/example_sp.ml]). Most relevant:
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

(* Pipe-only variant: ocamlobjinfo | inspect_ocaml.py — no redirect.
   Callers that capture stdout use this. *)
let inspect_pipe_cmd ~archive ?(watchlist = []) () =
  let script = "canary/scripts/inspect_ocaml.py" in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  [%string
    {|ocamlobjinfo '%{archive}' 2>/dev/null \
  | python3 %{script} --path '%{archive}' --watchlist '%{watchlist_csv}'|}]

(* Emit compact archive summary as summary.json.
   Module-level only (ocamlobjinfo doesn't expose constructors);
   constructor-level drift is detected via compile probes.
   See doc/canary/design/api_surface.md. *)
let inspect_cmd ~archive ?(watchlist = []) ~output_dir ~variant_key () =
  let out_file = Canary_basic.filename ~variant_key ~base:"inspect" ~ext:"json" in
  let pipe = inspect_pipe_cmd ~archive ~watchlist () in
  pipe ^ Printf.sprintf " \\\n  > %s/%s" output_dir out_file

(* Emit summary for an opam-installed OCaml package: inspects all its
   .cmxa/.cma archives via ocamlfind query + ocamlobjinfo, merged into one
   summary.json with combined module list.
   NOTE: [~pkg] must be the *ocamlfind* package name, not the opam package
   name. These can differ: e.g., opam has llvm.19-shared / llvm.dev-shared
   variants, but the ocamlfind package they all install is just "llvm". *)
let inspect_opam_pkg_cmd ~pkg ?(watchlist = []) ~output_dir ~variant_key () =
  let script = "canary/scripts/inspect_ocaml.py" in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  let out_file = Canary_basic.filename ~variant_key ~base:"inspect" ~ext:"json" in
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

(* Pipe-only mli summary from a single .mli file (or directory) path.
   Callers that capture stdout use this. For an opam-installed binding
   whose .mli files live under `ocamlfind query <pkg>`, use
   [mli_inspect_opam_pkg_cmd] below (this pipe is what it wraps). *)
let mli_inspect_pipe_cmd ~path ?(watchlist = []) () =
  let script = "canary/scripts/inspect_binding.py" in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  [%string
    {|python3 %{script} --kind mli --path '%{path}' --watchlist '%{watchlist_csv}'|}]

(* Source-level mli summary for an opam-installed OCaml binding.
   Discovers the package's .mli files via `ocamlfind query` and parses them
   with inspect_binding.py (grep-based, no compiler needed). Output JSON
   includes vals + constructors + module nesting (richer than ocamlobjinfo,
   which is module-level only).

   Use this when the binding ships .mli files in the install dir (LLVM does;
   z3 does too). When .mli files aren't installed, fall back to inspect_opam_pkg_cmd. *)
let mli_inspect_opam_pkg_cmd ~pkg ?(watchlist = []) ~output_dir ~variant_key () =
  let script = "canary/scripts/inspect_binding.py" in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  let out_file = Canary_basic.filename ~variant_key ~base:"inspect" ~ext:"json" in
  [%string
    {|eval $(opam env)
PKG_DIR=$(ocamlfind query '%{pkg}' 2>/dev/null)
test -n "$PKG_DIR"
python3 %{script} --kind mli --dir "$PKG_DIR" \
  --watchlist '%{watchlist_csv}' > %{output_dir}/%{out_file}|}]

(* Pipe-only c_stub summary from a .a archive path.
   Callers that capture stdout use this. *)
let stub_inspect_pipe_cmd ~path ?(prefix = "") ?(watchlist = []) () =
  let script = "canary/scripts/inspect_binding.py" in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  [%string
    {|python3 %{script} --kind stub --path '%{path}' --prefix '%{prefix}' --watchlist '%{watchlist_csv}'|}]

(* C-stub summary: undefined symbols a binding requires from its native lib.
   Discovers the binding's stub archive (lib<name>.a) via `ocamlfind query`,
   runs `nm` to collect undefined symbols, optionally filtered by a prefix
   (e.g. Z3_, LLVM). Output JSON has the consumer-side symbol set — pair
   with inspect_native.py output (provider side) for check_compat.
   Default filename "stub_inspect.json" so it can coexist with the OCaml-level
   "inspect.json" in the same probe output directory. *)
let stub_inspect_opam_pkg_cmd
    ~pkg ?(prefix = "") ?(watchlist = []) ~output_dir ~variant_key () =
  let script = "canary/scripts/inspect_binding.py" in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  (* v3 naming: "inspect_stub" (type-first), variant-keyed → "inspect_stub_19.json" *)
  let out_file = Canary_basic.filename ~variant_key ~base:"inspect_stub" ~ext:"json" in
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

(* Pipe-only python summary — no redirect. Optional [env] is a list of
   (var, value) pairs prepended to the invocation (e.g.
   [("PYTHONPATH", "..."); ("LD_LIBRARY_PATH", "...")]), which lets
   callers point the interpreter at an out-of-tree package without
   installing it. *)
let python_inspect_pipe_cmd ?(env = []) ~pkg ?(watchlist = [])
    ?(expect_missing = []) () =
  let script = "canary/scripts/inspect_python.py" in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  (* [expect_missing] — the EXPECTED-MISSING watchlist role (status §B):
     names DECLARED absent from the binding (e.g. sqlite's binding-lag
     markers). The JSON reports them as expected_missing.confirmed (still
     absent — an xfail-style pass) / .violated (appeared — declaration
     stale, alarming). Omitted when empty, so existing commands are
     byte-identical. *)
  let expect_missing_arg =
    if List.is_empty expect_missing then ""
    else
      Printf.sprintf " --expect-missing '%s'"
        (String.concat ~sep:"," expect_missing)
  in
  let env_prefix =
    List.map env ~f:(fun (k, v) -> Printf.sprintf "%s='%s'" k v)
    |> String.concat ~sep:" "
  in
  let sep = if String.is_empty env_prefix then "" else " " in
  [%string
    "%{env_prefix}%{sep}python3 %{script} --pkg '%{pkg}' --watchlist '%{watchlist_csv}'%{expect_missing_arg}"]

(* Emit compact Python package summary as summary.json via
   canary/scripts/inspect_python.py. Watchlist is a list of top-level
   attribute names; present/missing recorded in the JSON (and
   expected-missing role names via [expect_missing]).
   See doc/canary/ops/python_binding_gotchas.md. *)
let python_inspect_cmd ~pkg ?(watchlist = []) ?(expect_missing = [])
    ~output_dir ~variant_key () =
  let out_file = Canary_basic.filename ~variant_key ~base:"inspect" ~ext:"json" in
  let pipe = python_inspect_pipe_cmd ~pkg ~watchlist ~expect_missing () in
  pipe ^ Printf.sprintf " > %s/%s" output_dir out_file

(* L2: .cmi digest inspection for OCaml bindings.
   Runs md5sum on all .cmi files in the package directory, outputs JSON:
   { "kind": "cmi", "modules": { "Module": "d41d8cd9...", ... } }
   Detects type-level drift even when module/val names are unchanged. *)
let cmi_inspect_cmd ~pkg_dir ~output_dir ~variant_key () =
  let out_file = Canary_basic.filename ~variant_key ~base:"inspect_cmi" ~ext:"json" in
  [%string
    {|(echo '{"kind":"cmi","modules":{'
for f in "%{pkg_dir}"/*.cmi; do
  [ -f "$f" ] || continue
  mod=$(basename "$f" .cmi)
  hash=$(md5sum "$f" | cut -d' ' -f1)
  printf '"%s":"%s",' "$mod" "$hash"
done
echo '"":""}}' ) | sed 's/,"":""//' > %{output_dir}/%{out_file}|}]

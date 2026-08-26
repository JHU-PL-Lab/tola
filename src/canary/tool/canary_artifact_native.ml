open Base

(** Native library artifact ops — extraction of the {i s2 native_lib}
    surface (and, when reused on a binding artifact, {i s5 binding_lib}'s
    cext flavour).

    In surface-theory terms, this module is the OCaml-side glue that drives
    the [inspect_native.py] script. The same script + this glue cover two
    distinct artifact aliases depending on the input path:

    - {i n4 lib_native.so} — the project's compiled native library
      (e.g. tiny's [libtiny.so.1], z3's [libz3.so]).
    - {i bpe3 compiled_binding_cext.so} (or any cext flavour in another
      project) — a CPython C extension ELF, which {i is} a native lib
      from the toolchain's perspective even though surface theory
      classifies it as the consumer's compiled binding.

    Handles [.so] / [.dylib] / [.a] formats. Uses [nm] for symbol
    inspection. Platform detection lives here because it currently only
    affects nm flags ([-g] on macOS, [-D] on Linux) and native lib
    filename conventions. *)

(* ── Platform detection ── *)

let platform =
  let ic = Unix.open_process_in "uname -s 2>/dev/null" in
  let s = try String.strip (Stdlib.input_line ic) with End_of_file -> "" in
  ignore (Unix.close_process_in ic);
  s

let is_macos = String.equal platform "Darwin"

(* ── nm, per object format (2026-08-26) ──
   Two differences, and both are silent when got wrong: [nm -D] (list the
   DYNAMIC symbol table) is an ELF notion that macOS's nm rejects, and
   Mach-O prefixes every C symbol with an underscore, so a grep anchored
   on the bare name matches nothing on a lib that exports it perfectly.
   Callers building an nm pipeline by hand should use these rather than
   re-deriving the pair. (The [--strip-leading-underscore] seen further
   down is a flag to [inspect_native.py], NOT to nm — macOS nm has no
   such option.) *)

(** The flag that makes nm list a shared library's exported symbols. *)
let nm_dynamic_flag () : string = if is_macos then "-g" else "-D"

(** What the object format prepends to a C symbol's name in nm output:
    ["_"] for Mach-O, nothing for ELF. *)
let c_symbol_prefix () : string = if is_macos then "_" else ""

(* ── Kind predicates & existence checks ── *)

let is_native_lib path =
  let b = Stdlib.Filename.basename path in
  String.is_suffix path ~suffix:".so"
  || String.is_suffix path ~suffix:".dylib"
  || String.is_suffix path ~suffix:".a"
  || String.is_substring b ~substring:".so."
  || String.is_substring b ~substring:".dylib."

let exists_native_lib path =
  Stdlib.Sys.file_exists path && is_native_lib path

(* macOS: .dylib fallback when .so is requested *)
let exists_native_lib_or_dylib path =
  Stdlib.Sys.file_exists path
  || Stdlib.Sys.file_exists
       (Stdlib.Filename.remove_extension path ^ ".dylib")

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

(* ── Shell probe commands ── *)

(* Sanity probe: count symbols with prefix exported by a native lib.
   Writes probe.log; exits nonzero if the count is zero.
   Use to verify the lib compiled and exports the expected API surface. *)
let native_lib_probe_cmd ~lib ~prefix ~output_dir ~variant_key =
  let nm_flag = nm_dynamic_flag () in
  let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
  [%string
    {|COUNT=$(nm %{nm_flag} "%{lib}" 2>/dev/null | grep -v ' U ' | grep -c '%{prefix}' || echo 0)
printf '%{prefix} symbols exported: %s\n' "$COUNT" | tee %{output_dir}/%{probe_log}
test "$COUNT" -gt 0|}]

(* Emit compact artifact summary as summary.json.
   Dumps total symbol count, per-prefix counts, versioned-deps map (L1b),
   and a watchlist presence check. See doc/canary/design/api_surface.md. *)
(* Note: [lib] is embedded in double quotes so shell variable expansion works
   (e.g., passing "$LIB_Z3" from a resolve snippet). Callers using literal
   paths get the usual behavior; paths with shell metacharacters or spaces
   need escaping at the call site. *)
(* Pipe-only variant: same nm | inspect_native.py pipeline, no
   redirection. Callers that capture stdout (tiny's baseline/prepare
   inspectors) use this; [inspect_cmd] below composes it with a
   marker-file redirect for the runner path. *)
let inspect_pipe_cmd
    ~lib
    ?(prefixes = [])
    ?(watchlist = [])
    ?(emit_symbols = true)
    ?(elf = true)
    () =
  let nm_flag = nm_dynamic_flag () in
  let strip_flag = if is_macos then "--strip-leading-underscore " else "" in
  let script = "canary/scripts/inspect_native.py" in
  let prefixes_csv = String.concat ~sep:"," prefixes in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  let emit_flag = if emit_symbols then "--emit-symbols " else "" in
  let elf_flag = if elf then "--elf " else "" in
  [%string
    {|nm %{nm_flag} "%{lib}" 2>/dev/null \
  | python3 %{script} %{strip_flag}%{emit_flag}%{elf_flag}--path "%{lib}" --prefixes '%{prefixes_csv}' --watchlist '%{watchlist_csv}'|}]

let inspect_cmd ~lib ?(prefixes = []) ?(watchlist = []) ~output_dir ~variant_key () =
  let out_file = Canary_basic.filename ~variant_key ~base:"inspect" ~ext:"json" in
  let pipe = inspect_pipe_cmd ~lib ~prefixes ~watchlist () in
  pipe ^ Printf.sprintf " \\\n  > %s/%s" output_dir out_file

(* L4: ELF ABI metadata via readelf -d.  Captures SONAME, NEEDED, RPATH, RUNPATH.
   Writes inspect_elf.json to the output directory. *)
let elf_inspect_cmd ~lib ~output_dir ~variant_key () =
  let script = "canary/scripts/inspect_elf.py" in
  let out_file = Canary_basic.filename ~variant_key ~base:"inspect_elf" ~ext:"json" in
  [%string
    {|python3 %{script} --path "%{lib}" > %{output_dir}/%{out_file}|}]

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

(** Tiny baseline cache — OCaml port of
    [canary/examples/tiny/scenarios/scenarios.py:cmd_baseline].

    Phase C.3 of the Python→OCaml migration
    ([doc/canary/design/tiny_migration.md] §9). Produces the clean
    reference cache that [prepare <name>] later diffs against and
    that canary's tiny variants read via
    [Canary_project_tiny.cache_workspace_of].

    Per the sandbox-build decision ([tiny_migration.md] §1b):
    - artifacts/ and source/ snapshots are NOT produced (their only
      consumer was [restore-baseline], which the OCaml port drops).
    - inspect/ JSONs and workspace/ remain — consumed by prepare
      and by canary respectively.

    Inspector JSONs are produced by shelling out to the same Python
    inspector scripts under [canary/scripts/]; OCaml's job is
    orchestration, not parsing/emitting JSON itself. *)

open Base

(* ---------- paths ---------- *)

(** Path context for build + inspect steps. Baseline uses live-tree
    paths; prepare constructs sandbox paths that mirror the live-tree
    layout under a scenario cache dir. Threading a record instead of
    module-level constants lets both call the same primitives. *)
type paths = {
  tiny_root       : string;   (** dir containing c/, ocaml/, python_{cext,ctypes}/ *)
  c_build         : string;   (** libtiny.so.* output dir *)
  c_include       : string;   (** tiny.h dir *)
  ocaml_src       : string;   (** tiny.ml/.mli + tiny_stubs.c dir *)
  ocaml_build_dir : string;   (** tiny.cmxa + libtiny_stubs.a output dir *)
  python_cext_dir : string;   (** _native.cpython-*.so location *)
  python_cext_pkg : string;   (** dir containing python_cext/ + python_ctypes/ for PYTHONPATH *)
}

(** Live-tree paths (baseline default). *)
let live_paths : paths = {
  tiny_root       = "canary/examples/tiny";
  c_build         = "canary/examples/tiny/c/build";
  c_include       = "canary/examples/tiny/c/include";
  ocaml_src       = "canary/examples/tiny/ocaml";
  ocaml_build_dir = "_build/default/canary/examples/tiny/ocaml";
  python_cext_dir = "canary/examples/tiny/python_cext/tiny_cext";
  python_cext_pkg = "canary/examples/tiny";
}

(** Sandbox paths — [sandbox] is a copy of the tiny tree at some path.
    All artifacts land under the sandbox, keeping it self-contained
    and letting workspace materialization exclude the [_build/]
    fragment naturally. *)
let sandbox_paths ~(sandbox : string) : paths = {
  tiny_root       = sandbox;
  c_build         = sandbox ^ "/c/build";
  c_include       = sandbox ^ "/c/include";
  ocaml_src       = sandbox ^ "/ocaml";
  ocaml_build_dir = sandbox ^ "/_build/default/canary/examples/tiny/ocaml";
  python_cext_dir = sandbox ^ "/python_cext/tiny_cext";
  python_cext_pkg = sandbox;
}

(* Baseline cache — always at the fixed live-tree location, regardless
   of build paths. *)
let cache              = "canary/examples/tiny/scenarios/_cache"
let baseline_cache     = cache ^ "/baseline"
let baseline_inspect   = baseline_cache ^ "/inspect"
let baseline_workspace = baseline_cache ^ "/workspace"
let baseline_cext      = baseline_cache ^ "/artifacts/cext"

(* Scripts path — always relative to project root. *)
let scripts            = "canary/scripts"

(* Backward-compatible top-level aliases for the existing baseline
   build/inspect/workspace code, which was written before the [paths]
   record. Reference [live_paths]. Note [c_include] and [tiny_src] /
   [tiny_libtiny] / [tiny_cmxa] / [tiny_stubs_a] are re-derived from
   these below and don't need aliases here. *)
let tiny_root       = live_paths.tiny_root
let c_build         = live_paths.c_build
let ocaml_build_dir = live_paths.ocaml_build_dir

(* ---------- subprocess helpers ---------- *)

let warn fmt = Stdlib.Printf.ksprintf (fun s -> Stdlib.prerr_endline ("baseline: " ^ s)) fmt
let info fmt = Stdlib.Printf.ksprintf (fun s -> Stdlib.prerr_endline ("baseline: " ^ s)) fmt
let fail fmt = Stdlib.Printf.ksprintf (fun s -> Stdlib.prerr_endline ("baseline: " ^ s); Stdlib.exit 1) fmt

(** Run a shell command; return its exit code. stdout/stderr go to
    the inherited fds. *)
let run_shell (cmd : string) : int =
  Stdlib.Sys.command cmd

let mkdir_p p =
  if not (Stdlib.Sys.file_exists p) then
    let _ = run_shell (Printf.sprintf "mkdir -p '%s'" p) in ()

let rm_rf p =
  if Stdlib.Sys.file_exists p then
    let _ = run_shell (Printf.sprintf "rm -rf '%s'" p) in ()

(** Run a shell pipeline and capture stdout. Returns [Some json] on
    success + parseable JSON; [None] on subprocess error or invalid
    JSON. Matches Python [_sh_json]. *)
let capture_json (cmd : string) : Yojson.Basic.t option =
  let ic = Unix.open_process_in (cmd ^ " 2>/dev/null") in
  let buf = Stdlib.Buffer.create 4096 in
  (try
     while true do
       Stdlib.Buffer.add_channel buf ic 4096
     done
   with End_of_file -> ());
  let status = Unix.close_process_in ic in
  match status with
  | Unix.WEXITED 0 ->
    let s = Stdlib.Buffer.contents buf in
    if String.is_empty (String.strip s) then None
    else (try Some (Yojson.Basic.from_string s) with _ -> None)
  | _ -> None

(* ---------- direct-compile builds ---------- *)

(** [baseline] builds tiny's artifacts by invoking compilers
    directly (gcc, ocamlfind ocamlopt, ar). No cmake, no dune, no
    make.

    Rationale ([tiny_migration.md] §1b update, 2026-06-26): for
    artifacts canary *owns* (tiny is designed by canary, not an
    upstream project), the "owner decides the build" principle
    picks direct compilers over external build systems. This
    dissolves the dune-in-dune lock issue definitively (no dune
    subprocess exists), matches "less external build systems"
    while keeping "external tools ok" (compilers are tools), and
    makes flags visible + auditable rather than hidden inside
    cmake/dune generators.

    Output paths: preserved at their previous (cmake/dune)
    locations to avoid rippling into workspace materialization
    and inspector paths. The [_build/default/…] path is now
    misleading (dune no longer produces those files) but the
    change is contained.

    For real upstream projects (z3, llvm, sqlite), canary
    continues to shell out to their own build systems — we're a
    guest, not the owner. *)

let tiny_cmxa     = ocaml_build_dir ^ "/tiny.cmxa"
let tiny_stubs_a  = ocaml_build_dir ^ "/libtiny_stubs.a"
let tiny_libtiny  = c_build ^ "/libtiny.so.1"
let tiny_src      = tiny_root ^ "/ocaml"
let c_include     = tiny_root ^ "/c/include"

(** Run a shell command; if it fails, log and return false. *)
let run_or_warn (label : string) (cmd : string) : bool =
  match run_shell cmd with
  | 0 -> true
  | rc ->
    warn "%s failed (exit %d)" label rc;
    warn "  cmd: %s" cmd;
    false

let capture_line (cmd : string) : string =
  let ic = Unix.open_process_in (cmd ^ " 2>/dev/null") in
  let s = try Stdlib.input_line ic with End_of_file -> "" in
  let _ = Unix.close_process_in ic in
  String.strip s

(** C library — libtiny.so.1.0 + symlinks libtiny.so.1, libtiny.so.
    Symbol versioning via c/tiny.map (TINY_1.0 exports). *)
let build_c_lib () : bool =
  info "compile C library";
  mkdir_p c_build;
  run_or_warn "cc tiny.c"
    (Printf.sprintf "gcc -c -fPIC -I%s %s/c/src/tiny.c -o %s/tiny.o"
       c_include tiny_root c_build)
  && run_or_warn "link libtiny.so.1.0"
       (Printf.sprintf
          "gcc -shared -Wl,-soname,libtiny.so.1 \
           -Wl,--version-script=%s/c/tiny.map %s/tiny.o -o %s/libtiny.so.1.0"
          tiny_root c_build c_build)
  && run_or_warn "symlink libtiny.so.1"
       (Printf.sprintf "ln -sf libtiny.so.1.0 %s/libtiny.so.1" c_build)
  && run_or_warn "symlink libtiny.so"
       (Printf.sprintf "ln -sf libtiny.so.1 %s/libtiny.so" c_build)
  && (let _ = run_shell (Printf.sprintf "rm -f %s/tiny.o" c_build) in true)

(** OCaml binding — tiny.cmxa + libtiny_stubs.a.

    Sequence: compile the two .mli → .cmi, the two .ml → .cmx,
    the tiny_stubs.c → .o, archive stubs → libtiny_stubs.a, pack
    the .cmx list → tiny.cmxa with cclib flags recording the
    consumer-side link needs (-ltiny -ltiny_stubs).

    Module wrapping: dune produced [Tiny__ / Tiny__Tiny_raw /
    Tiny] via its wrapper-module convention; direct-compile
    produces plain [Tiny_raw / Tiny]. Simpler, no false top-level
    module. Cosmetic drift in bo6.modules; no consumer script
    depends on the specific names (see tiny_ocaml_module_watchlist
    which is [Tiny; Tiny.sum; …] — [Tiny] present either way). *)
let build_ocaml_binding () : bool =
  info "compile OCaml binding";
  mkdir_p ocaml_build_dir;
  let ocaml_where = capture_line "ocamlc -where" in
  if String.is_empty ocaml_where then begin
    warn "ocamlc -where returned empty; is opam env set?";
    false
  end
  else
    let cmi src target =
      Printf.sprintf "ocamlfind ocamlopt -bin-annot -I %s -c %s/%s -o %s/%s"
        ocaml_build_dir tiny_src src ocaml_build_dir target
    in
    (* Compile .mli → .cmi, then .ml → .cmx. Order matters:
       tiny.ml depends on Tiny_raw.cmi. *)
    run_or_warn "cc tiny_raw.mli" (cmi "tiny_raw.mli" "tiny_raw.cmi")
    && run_or_warn "cc tiny_raw.ml"  (cmi "tiny_raw.ml"  "tiny_raw.cmx")
    && run_or_warn "cc tiny.mli"     (cmi "tiny.mli"     "tiny.cmi")
    && run_or_warn "cc tiny.ml"      (cmi "tiny.ml"      "tiny.cmx")
    && run_or_warn "cc tiny_stubs.c"
         (Printf.sprintf
            "gcc -c -fPIC -I%s -I%s %s/tiny_stubs.c -o %s/tiny_stubs.o"
            ocaml_where c_include tiny_src ocaml_build_dir)
    && run_or_warn "ar libtiny_stubs.a"
         (Printf.sprintf "ar rcs %s/libtiny_stubs.a %s/tiny_stubs.o"
            ocaml_build_dir ocaml_build_dir)
    && run_or_warn "ar tiny.cmxa"
         (Printf.sprintf
            "ocamlfind ocamlopt -a %s/tiny_raw.cmx %s/tiny.cmx \
             -cclib -ltiny -cclib -ltiny_stubs -o %s/tiny.cmxa"
            ocaml_build_dir ocaml_build_dir ocaml_build_dir)

(** Python cext — _native.cpython-*.so. Embeds NEEDED
    libtiny.so.1 + rpath to c/build (matching setup.py's
    runtime_library_dirs). Later workspace materialization strips
    the rpath so LD_LIBRARY_PATH takes over. *)
let build_python_cext () : bool =
  info "compile Python cext";
  (* Use sysconfig directly — python3-config is not always shipped
     (venv installs may omit it; uv-managed Python does). *)
  let py_include =
    capture_line
      "python3 -c 'import sysconfig; print(sysconfig.get_paths()[\"include\"])'"
  in
  let ext_suffix =
    capture_line
      "python3 -c 'import sysconfig; print(sysconfig.get_config_var(\"EXT_SUFFIX\"))'"
  in
  if String.is_empty py_include || String.is_empty ext_suffix then begin
    warn "python3 sysconfig unavailable; skipping cext";
    false
  end
  else
    let c_build_abs =
      capture_line (Printf.sprintf "readlink -f %s" c_build)
    in
    let src = tiny_root ^ "/python_cext/tiny_cext/_native.c" in
    let dst =
      Printf.sprintf "%s/python_cext/tiny_cext/_native%s" tiny_root ext_suffix
    in
    run_or_warn "cc _native.so"
      (Printf.sprintf
         "gcc -shared -fPIC -I%s -I%s -L%s -Wl,-rpath,%s %s -ltiny -o %s"
         py_include c_include c_build_abs c_build_abs src dst)

(* ---------- glob ---------- *)

let glob_first ~root ~pattern : string option =
  (* Use shell glob via find; simpler than walking with regex. *)
  let cmd = Printf.sprintf "find '%s' -name '%s' 2>/dev/null | head -1" root pattern in
  let ic = Unix.open_process_in cmd in
  let r = try Some (Stdlib.input_line ic) with End_of_file -> None in
  let _ = Unix.close_process_in ic in
  match r with
  | Some s when not (String.is_empty (String.strip s)) -> Some (String.strip s)
  | _ -> None

(* ---------- inspectors ---------- *)

let inspect_n4 () =
  (* nm -D libtiny.so.1 | inspect_native.py *)
  let so = c_build ^ "/libtiny.so.1" in
  let so =
    if Stdlib.Sys.file_exists so then so
    else
      (* SONAME-bumped fallback (libtiny.so.*.0). *)
      Option.value (glob_first ~root:c_build ~pattern:"libtiny.so.*.0") ~default:so
  in
  if not (Stdlib.Sys.file_exists so) then None
  else
    capture_json
      (Printf.sprintf
         "nm -D '%s' | python3 '%s/inspect_native.py' \
          --path '%s' --prefixes tiny_ --elf --emit-symbols"
         so scripts so)

let inspect_bo4 () =
  let mli = tiny_root ^ "/ocaml/tiny.mli" in
  if not (Stdlib.Sys.file_exists mli) then None
  else
    capture_json
      (Printf.sprintf "python3 '%s/inspect_binding.py' --kind mli --path '%s'" scripts mli)

let inspect_bo6 () =
  match glob_first ~root:ocaml_build_dir ~pattern:"tiny.cmxa" with
  | None -> None
  | Some cmxa ->
    capture_json (Printf.sprintf "python3 '%s/inspect_ocaml.py' --path '%s'" scripts cmxa)

let inspect_bo7 () =
  match glob_first ~root:ocaml_build_dir ~pattern:"libtiny_stubs*.a" with
  | None -> None
  | Some stub_a ->
    capture_json
      (Printf.sprintf
         "python3 '%s/inspect_binding.py' --kind stub --path '%s' --prefix tiny_"
         scripts stub_a)

let inspect_bpc2 () =
  capture_json
    (Printf.sprintf
       "PYTHONPATH='%s/python_ctypes' LD_LIBRARY_PATH='%s' \
        python3 '%s/inspect_python.py' --pkg tiny_ctypes"
       tiny_root c_build scripts)

let inspect_bpe2 () =
  capture_json
    (Printf.sprintf
       "PYTHONPATH='%s/python_cext' LD_LIBRARY_PATH='%s' \
        python3 '%s/inspect_python.py' --pkg tiny_cext"
       tiny_root c_build scripts)

let inspect_bpe3 () =
  (* nm -u + filter tiny_ + wrap as c_stub JSON. Inline Python (parity
     with scenarios.py's bpe3); could be ported to pure OCaml later. *)
  match
    glob_first
      ~root:(tiny_root ^ "/python_cext/tiny_cext")
      ~pattern:"_native.cpython-*.so"
  with
  | None -> None
  | Some so ->
    capture_json
      (Printf.sprintf
         "nm -u '%s' | awk '/^[[:space:]]*U /{print $NF}' | sort -u | \
          python3 -c \"import json,sys; \
          syms=[l.strip() for l in sys.stdin if l.strip() and l.strip().startswith('tiny_')]; \
          json.dump({'kind':'c_stub','path':'%s','counts':{'required':len(syms)},'requires':sorted(syms)}, sys.stdout)\""
         so so)

let inspectors : (string * (unit -> Yojson.Basic.t option)) list = [
  "n4",   inspect_n4;
  "bo4",  inspect_bo4;
  "bo6",  inspect_bo6;
  "bo7",  inspect_bo7;
  "bpc2", inspect_bpc2;
  "bpe2", inspect_bpe2;
  "bpe3", inspect_bpe3;
]

(* ---------- workspace materialization ---------- *)

let workspace_excluded_top =
  [ "scenarios"; "test"; "README.md"; "Makefile" ]

let workspace_excluded_fragments = [ "_build"; "__pycache__" ]

let workspace_excluded_prefixes = [
  "python_cext/build/";
  "python_cext/tiny_cext.egg-info/";
  "c/build/CMakeFiles/";
  "c/build/CMakeCache.txt";
  "c/build/cmake_install.cmake";
  "c/build/Makefile";
]

let path_contains_fragment ~fragments parts =
  List.exists fragments ~f:(fun frag ->
    List.exists parts ~f:(String.equal frag))

let starts_with_any ~prefixes s =
  List.exists prefixes ~f:(fun pfx -> String.is_prefix s ~prefix:pfx)

let copy_file_or_symlink ~src ~dst =
  match (Unix.lstat src).st_kind with
  | Unix.S_LNK ->
    let target = Unix.readlink src in
    rm_rf dst;
    Unix.symlink target dst
  | _ ->
    (* Force overwrite; preserve mode via cp -p *)
    let _ = run_shell (Printf.sprintf "cp -P -p '%s' '%s'" src dst) in
    ()

(** Walk a directory tree; call [f rel_path src_path] for every file
    or symlink (not directories). [rel_path] is relative to [root]
    using forward slashes. *)
let rec walk ~root ~rel ~f =
  let abs = if String.is_empty rel then root else root ^ "/" ^ rel in
  match (Unix.lstat abs).st_kind with
  | Unix.S_DIR ->
    Stdlib.Sys.readdir abs
    |> Array.iter ~f:(fun name ->
      let rel' = if String.is_empty rel then name else rel ^ "/" ^ name in
      walk ~root ~rel:rel' ~f)
  | Unix.S_REG | Unix.S_LNK -> f rel abs
  | _ -> ()

let materialize_workspace () : int =
  let ws = baseline_workspace in
  rm_rf ws; mkdir_p ws;
  let count = ref 0 in
  (* Walk each top-level entry; skip excluded names. *)
  Stdlib.Sys.readdir tiny_root
  |> Array.iter ~f:(fun top ->
    if List.mem workspace_excluded_top top ~equal:String.equal then ()
    else
      walk ~root:tiny_root ~rel:top ~f:(fun rel src ->
        let parts = String.split rel ~on:'/' in
        if path_contains_fragment ~fragments:workspace_excluded_fragments parts then ()
        else if starts_with_any ~prefixes:workspace_excluded_prefixes rel then ()
        else begin
          let dst = ws ^ "/" ^ rel in
          let dst_dir = Stdlib.Filename.dirname dst in
          mkdir_p dst_dir;
          copy_file_or_symlink ~src ~dst;
          Int.incr count
        end));
  (* Minimal standalone dune-project. *)
  Stdlib.(let oc = open_out (ws ^ "/dune-project") in
          output_string oc "(lang dune 3.10)\n";
          close_out oc);
  Int.incr count;
  (* Strip RUNPATH from cext .so so dyld respects LD_LIBRARY_PATH. *)
  if run_shell "command -v patchelf >/dev/null 2>&1" = 0 then begin
    let cext_dir = ws ^ "/python_cext/tiny_cext" in
    if Stdlib.Sys.file_exists cext_dir then
      Stdlib.Sys.readdir cext_dir
      |> Array.iter ~f:(fun name ->
        if String.is_prefix name ~prefix:"_native.cpython-"
        && String.is_suffix name ~suffix:".so" then
          let _ = run_shell (Printf.sprintf "patchelf --remove-rpath '%s/%s' 2>/dev/null"
                              cext_dir name) in ())
  end;
  (* Ensure libtiny.so symlink in workspace c/build (point at highest-versioned). *)
  let ws_c_build = ws ^ "/c/build" in
  let libtiny_so = ws_c_build ^ "/libtiny.so" in
  if Stdlib.Sys.file_exists ws_c_build && not (Stdlib.Sys.file_exists libtiny_so) then begin
    let candidates =
      Stdlib.Sys.readdir ws_c_build
      |> Array.to_list
      |> List.filter ~f:(fun n ->
        String.is_prefix n ~prefix:"libtiny.so."
        && not (String.is_substring n ~substring:".bak.")
        && (match String.chop_prefix n ~prefix:"libtiny.so." with
            | Some suffix -> String.for_all suffix ~f:Char.is_digit
            | None -> false))
      |> List.sort ~compare:(fun a b -> String.compare b a) (* reverse *)
    in
    match candidates with
    | top :: _ -> Unix.symlink top libtiny_so
    | [] -> ()
  end;
  !count

(* ---------- orchestrator ---------- *)

let save_json path (j : Yojson.Basic.t) =
  let s = Yojson.Basic.pretty_to_string j in
  Stdlib.(let oc = open_out path in
          output_string oc s;
          output_char oc '\n';
          close_out oc)

(** Snapshot the freshly-built cext .so to [_cache/baseline/artifacts/cext/].
    Prepare later copies this into each scenario sandbox instead of
    rebuilding, preserving the baseline cext's NEEDED entries — critical
    for scenarios like [symbol_version_floor] where the sandbox libtiny
    exports [TINY_2.0] but cext must keep referencing [TINY_1.0] for the
    detection to fire. *)
let snapshot_baseline_cext () : unit =
  mkdir_p baseline_cext;
  let src_dir = live_paths.python_cext_dir in
  if Stdlib.Sys.file_exists src_dir then
    Stdlib.Sys.readdir src_dir
    |> Array.iter ~f:(fun name ->
      if String.is_prefix name ~prefix:"_native.cpython-"
      && String.is_suffix name ~suffix:".so" then
        let _ = run_shell
          (Printf.sprintf "cp -P -p '%s/%s' '%s/'" src_dir name baseline_cext)
        in ())

let run () : unit =
  if not (build_c_lib ())        then fail "C library build failed";
  if not (build_ocaml_binding ()) then fail "OCaml binding build failed";
  if not (build_python_cext ())   then fail "Python cext build failed";
  mkdir_p baseline_inspect;
  info "artifacts built; running inspectors";
  List.iter inspectors ~f:(fun (alias, fn) ->
    match fn () with
    | None -> warn "WARN %s produced no JSON" alias
    | Some j ->
      let path = Printf.sprintf "%s/%s.json" baseline_inspect alias in
      save_json path j;
      info "%s -> %s" alias path);
  snapshot_baseline_cext ();
  info "snapshot baseline cext -> %s" baseline_cext;
  let n = materialize_workspace () in
  info "snapshot workspace (%d files)" n

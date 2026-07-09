(** Tiny workspace materialisation — both baseline (clean
    reference) and prepare (per-scenario perturbed sandbox).
    Merged from the former [Canary_tiny_baseline] +
    [Canary_tiny_prepare] modules 2026-07-08.

    Two top-level entry points:
    - {!run_baseline} builds tiny cleanly from the live tree,
      inspects, snapshots the cext, and materialises
      [_cache/baseline/workspace/].
    - {!run_prepare} applies one scenario's perturbation in a
      hermetic sandbox ([_cache/<name>/sandbox/]), builds,
      inspects, computes surface deltas vs baseline, writes
      [confirm_ill.json], and materialises
      [_cache/<name>/workspace/].
    - {!run_prepare_all} is [run_prepare] over every scenario;
      {!confirm} prints a cached [confirm_ill.json].

    Sandbox-build design ([worklog/tiny_migration.md] §1b):
    the live tree is never mutated. Each scenario's sandbox
    copies the live sources; patches / rebuilds / SONAME bumps
    all happen inside the sandbox.

    Cext handling: the sandbox does NOT rebuild
    [_native.cpython-*.so]. It copies the baseline-cached one
    instead — preserves baseline's NEEDED entries, critical
    for scenarios like [symbol_version_floor].

    Build/inspect primitives take a {!paths} record so both
    baseline (live-tree paths) and prepare (sandbox paths) call
    one set of functions. Audit §7.7 step (3) "cheapest first
    step" already applied.

    Legacy port note: Phase C.3 / C.4 of the Python→OCaml
    migration; see [doc/canary/worklog/tiny_migration.md] §9. *)

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

(* Backward-compatible top-level aliases still used by
   [snapshot_baseline_cext] and by consumers reading baseline
   cache paths. Reference [live_paths]. Build/inspect/materialize
   primitives now take [~paths] explicitly. *)
let tiny_root       = live_paths.tiny_root
let c_build         = live_paths.c_build

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

    Rationale ([worklog/tiny_migration.md] §1b update, 2026-06-26): for
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
let build_c_lib ~(paths : paths) () : bool =
  info "compile C library";
  mkdir_p paths.c_build;
  run_or_warn "cc tiny.c"
    (Printf.sprintf "gcc -c -fPIC -I%s %s/c/src/tiny.c -o %s/tiny.o"
       paths.c_include paths.tiny_root paths.c_build)
  && run_or_warn "link libtiny.so.1.0"
       (Printf.sprintf
          "gcc -shared -Wl,-soname,libtiny.so.1 \
           -Wl,--version-script=%s/c/tiny.map %s/tiny.o -o %s/libtiny.so.1.0"
          paths.tiny_root paths.c_build paths.c_build)
  && run_or_warn "symlink libtiny.so.1"
       (Printf.sprintf "ln -sf libtiny.so.1.0 %s/libtiny.so.1" paths.c_build)
  && run_or_warn "symlink libtiny.so"
       (Printf.sprintf "ln -sf libtiny.so.1 %s/libtiny.so" paths.c_build)
  && (let _ = run_shell (Printf.sprintf "rm -f %s/tiny.o" paths.c_build) in true)

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
let build_ocaml_binding ~(paths : paths) () : bool =
  info "compile OCaml binding";
  mkdir_p paths.ocaml_build_dir;
  let ocaml_where = capture_line "ocamlc -where" in
  if String.is_empty ocaml_where then begin
    warn "ocamlc -where returned empty; is opam env set?";
    false
  end
  else
    let cmi src target =
      Printf.sprintf "ocamlfind ocamlopt -bin-annot -I %s -c %s/%s -o %s/%s"
        paths.ocaml_build_dir paths.ocaml_src src paths.ocaml_build_dir target
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
            ocaml_where paths.c_include paths.ocaml_src paths.ocaml_build_dir)
    && run_or_warn "ar libtiny_stubs.a"
         (Printf.sprintf "ar rcs %s/libtiny_stubs.a %s/tiny_stubs.o"
            paths.ocaml_build_dir paths.ocaml_build_dir)
    && run_or_warn "ar tiny.cmxa"
         (Printf.sprintf
            "ocamlfind ocamlopt -a %s/tiny_raw.cmx %s/tiny.cmx \
             -cclib -ltiny -cclib -ltiny_stubs -o %s/tiny.cmxa"
            paths.ocaml_build_dir paths.ocaml_build_dir paths.ocaml_build_dir)

(** Python cext — _native.cpython-*.so. Embeds NEEDED
    libtiny.so.1 + rpath to c/build (matching setup.py's
    runtime_library_dirs). Later workspace materialization strips
    the rpath so LD_LIBRARY_PATH takes over. *)
let build_python_cext ~(paths : paths) () : bool =
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
      capture_line (Printf.sprintf "readlink -f %s" paths.c_build)
    in
    let src = paths.tiny_root ^ "/python_cext/tiny_cext/_native.c" in
    let dst =
      Printf.sprintf "%s/python_cext/tiny_cext/_native%s"
        paths.tiny_root ext_suffix
    in
    run_or_warn "cc _native.so"
      (Printf.sprintf
         "gcc -shared -fPIC -I%s -I%s -L%s -Wl,-rpath,%s %s -ltiny -o %s"
         py_include paths.c_include c_build_abs c_build_abs src dst)

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

let inspect_n4 ~(paths : paths) () =
  (* nm -D libtiny.so.1 | inspect_native.py *)
  let so = paths.c_build ^ "/libtiny.so.1" in
  let so =
    if Stdlib.Sys.file_exists so then so
    else
      (* SONAME-bumped fallback (libtiny.so.*.0). *)
      Option.value (glob_first ~root:paths.c_build ~pattern:"libtiny.so.*.0")
        ~default:so
  in
  if not (Stdlib.Sys.file_exists so) then None
  else
    capture_json
      (Printf.sprintf
         "nm -D '%s' | python3 '%s/inspect_native.py' \
          --path '%s' --prefixes tiny_ --elf --emit-symbols"
         so scripts so)

let inspect_bo4 ~(paths : paths) () =
  let mli = paths.ocaml_src ^ "/tiny.mli" in
  if not (Stdlib.Sys.file_exists mli) then None
  else
    capture_json
      (Printf.sprintf "python3 '%s/inspect_binding.py' --kind mli --path '%s'"
         scripts mli)

let inspect_bo6 ~(paths : paths) () =
  match glob_first ~root:paths.ocaml_build_dir ~pattern:"tiny.cmxa" with
  | None -> None
  | Some cmxa ->
    capture_json
      (Printf.sprintf "python3 '%s/inspect_ocaml.py' --path '%s'" scripts cmxa)

let inspect_bo7 ~(paths : paths) () =
  match glob_first ~root:paths.ocaml_build_dir ~pattern:"libtiny_stubs*.a" with
  | None -> None
  | Some stub_a ->
    capture_json
      (Printf.sprintf
         "python3 '%s/inspect_binding.py' --kind stub --path '%s' --prefix tiny_"
         scripts stub_a)

let inspect_bpc2 ~(paths : paths) () =
  capture_json
    (Printf.sprintf
       "PYTHONPATH='%s/python_ctypes' LD_LIBRARY_PATH='%s' \
        python3 '%s/inspect_python.py' --pkg tiny_ctypes"
       paths.python_cext_pkg paths.c_build scripts)

let inspect_bpe2 ~(paths : paths) () =
  capture_json
    (Printf.sprintf
       "PYTHONPATH='%s/python_cext' LD_LIBRARY_PATH='%s' \
        python3 '%s/inspect_python.py' --pkg tiny_cext"
       paths.python_cext_pkg paths.c_build scripts)

let inspect_bpe3 ~(paths : paths) () =
  (* nm -u + filter tiny_ + wrap as c_stub JSON. Inline Python (parity
     with scenarios.py's bpe3); could be ported to pure OCaml later. *)
  match
    glob_first ~root:paths.python_cext_dir
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

let inspectors ~(paths : paths)
  : (string * (unit -> Yojson.Basic.t option)) list = [
  "n4",   (fun () -> inspect_n4  ~paths ());
  "bo4",  (fun () -> inspect_bo4 ~paths ());
  "bo6",  (fun () -> inspect_bo6 ~paths ());
  "bo7",  (fun () -> inspect_bo7 ~paths ());
  "bpc2", (fun () -> inspect_bpc2 ~paths ());
  "bpe2", (fun () -> inspect_bpe2 ~paths ());
  "bpe3", (fun () -> inspect_bpe3 ~paths ());
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

let materialize_workspace ~(paths : paths) ~(target : string) : int =
  let ws = target in
  rm_rf ws; mkdir_p ws;
  let count = ref 0 in
  (* Walk each top-level entry; skip excluded names. *)
  Stdlib.Sys.readdir paths.tiny_root
  |> Array.iter ~f:(fun top ->
    if List.mem workspace_excluded_top top ~equal:String.equal then ()
    else
      walk ~root:paths.tiny_root ~rel:top ~f:(fun rel src ->
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

let run_baseline () : unit =
  let paths = live_paths in
  if not (build_c_lib ~paths ())        then fail "C library build failed";
  if not (build_ocaml_binding ~paths ()) then fail "OCaml binding build failed";
  if not (build_python_cext ~paths ())   then fail "Python cext build failed";
  mkdir_p baseline_inspect;
  info "artifacts built; running inspectors";
  List.iter (inspectors ~paths) ~f:(fun (alias, fn) ->
    match fn () with
    | None -> warn "WARN %s produced no JSON" alias
    | Some j ->
      let path = Printf.sprintf "%s/%s.json" baseline_inspect alias in
      save_json path j;
      info "%s -> %s" alias path);
  snapshot_baseline_cext ();
  info "snapshot baseline cext -> %s" baseline_cext;
  let n = materialize_workspace ~paths ~target:baseline_workspace in
  info "snapshot workspace (%d files)" n

(* ================================================================== *)
(* {1 Prepare — perturbed sandbox per scenario}                       *)
(* ================================================================== *)

(** Prepare-side log helpers use a "prepare:" prefix so output is
    distinguishable when {!run_prepare_all} is invoked. Baseline
    helpers keep "baseline:" — misleading when prepare calls
    {!build_c_lib} and warns fire from the shared path, but the
    audit noted this cosmetic issue is minor. *)
let prep_warn fmt =
  Stdlib.Printf.ksprintf
    (fun s -> Stdlib.prerr_endline ("prepare: " ^ s)) fmt
let prep_info fmt =
  Stdlib.Printf.ksprintf
    (fun s -> Stdlib.prerr_endline ("prepare: " ^ s)) fmt
let prep_fail fmt =
  Stdlib.Printf.ksprintf
    (fun s -> Stdlib.prerr_endline ("prepare: " ^ s); Stdlib.exit 1) fmt

(* Per-scenario cache paths. *)
let scen_cache_of ~name = Printf.sprintf "%s/%s" cache name
let scen_sandbox_of ~name = scen_cache_of ~name ^ "/sandbox"
let scen_inspect_of ~name = scen_cache_of ~name ^ "/inspect"
let scen_workspace_of ~name = scen_cache_of ~name ^ "/workspace"

let patches_dir = live_paths.tiny_root ^ "/scenarios/patches"

(* ---------- sandbox setup ---------- *)

let copy_live_to_sandbox ~sandbox : bool =
  rm_rf sandbox;
  mkdir_p sandbox;
  let cmd =
    Printf.sprintf
      "rsync -a --exclude=_build --exclude=__pycache__ \
       --exclude=scenarios/_cache --exclude='python_cext/build' \
       --exclude='python_cext/tiny_cext.egg-info' \
       --exclude='c/build/CMakeFiles' --exclude='c/build/CMakeCache.txt' \
       --exclude='c/build/cmake_install.cmake' --exclude='c/build/Makefile' \
       '%s/' '%s/'"
      live_paths.tiny_root sandbox
  in
  run_shell cmd = 0

let install_baseline_cext ~sandbox : bool =
  let src_dir = baseline_cext in
  let dst_dir = sandbox ^ "/python_cext/tiny_cext" in
  if not (Stdlib.Sys.file_exists src_dir) then begin
    prep_warn "baseline cext not found at %s; run baseline first" src_dir;
    false
  end
  else begin
    mkdir_p dst_dir;
    run_shell
      (Printf.sprintf "cp -P -p %s/_native.cpython-*.so '%s/'" src_dir dst_dir)
    = 0
  end

(* ---------- perturbation application ---------- *)

let apply_patch ~sandbox ~patch_file : bool =
  let full_patch = patches_dir ^ "/" ^ patch_file in
  if not (Stdlib.Sys.file_exists full_patch) then begin
    prep_warn "patch file missing: %s" full_patch; false
  end
  else
    run_shell
      (Printf.sprintf "cd '%s' && patch -p1 < '%s/%s' > /dev/null"
         sandbox
         (capture_line (Printf.sprintf "readlink -f %s" patches_dir))
         patch_file) = 0

let apply_soname_bump ~sandbox ~from_so:_ ~to_so : bool =
  let c_build = sandbox ^ "/c/build" in
  let major_so =
    match String.chop_suffix to_so ~suffix:".0" with
    | Some s -> s
    | None -> to_so
  in
  let steps = [
    Printf.sprintf "mv '%s/libtiny.so.1.0' '%s/%s'" c_build c_build to_so;
    Printf.sprintf "rm -f '%s/libtiny.so' '%s/libtiny.so.1'" c_build c_build;
    Printf.sprintf "ln -sf '%s' '%s/%s'" to_so c_build major_so;
    Printf.sprintf "ln -sf '%s' '%s/libtiny.so'" major_so c_build;
    Printf.sprintf "patchelf --set-soname '%s' '%s/%s' 2>/dev/null || true"
      major_so c_build to_so;
  ] in
  List.for_all steps ~f:(fun cmd -> run_shell cmd = 0)

(* ---------- surface delta (mirrors Python _surface_delta) ---------- *)

let string_set_of_json = function
  | `List xs ->
    List.filter_map xs ~f:(function `String s -> Some s | _ -> None)
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
      (perturbed : Yojson.Basic.t option)
    : Yojson.Basic.t option =
  match baseline, perturbed with
  | None, None -> Some (`Assoc [ "status", `String "both_absent" ])
  | None, Some p ->
    Some (`Assoc [ "status", `String "baseline_absent"; "perturbed", p ])
  | Some _, None ->
    Some (`Assoc [ "status", `String "perturbed_absent" ])
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
                       "perturbed", opt_to_json ps ])
    in
    let needed_delta = field_diff elf_b elf_p "needed" in
    let all = field_deltas
              @ Option.to_list soname_delta
              @ Option.to_list needed_delta in
    match all with [] -> None | xs -> Some (`Assoc xs)

(* ---------- confirm_ill.json ---------- *)

let violates_label = Canary_tiny_scenario.violates_label

let confirm_of
    ~(entry : Canary_tiny_scenario.entry)
    ~(build_status : Yojson.Basic.t)
    ~(deltas : (string * Yojson.Basic.t) list)
  : Yojson.Basic.t =
  let scenario = entry.scenario in
  let recipe = entry.recipe in
  let violates_json =
    `List (List.map recipe.violates ~f:(fun c -> `String (violates_label c))) in
  let perturbs_json =
    `List (List.map recipe.perturbs ~f:(fun s -> `String s)) in
  `Assoc [
    "scenario",    `String scenario.name;
    "description", `String scenario.description;
    "perturbs",    perturbs_json;
    "violates",    violates_json;
    "build",       build_status;
    "deltas",      `Assoc deltas;
  ]

(* ---------- workspace materialisation from sandbox ---------- *)

(** Copy the sandbox into workspace/, excluding build fragments.
    Distinct from {!materialize_workspace} which walks the live tree
    (from [~paths]) — this one uses rsync from a pre-built sandbox.
    Two implementations kept separate for now; unify under the
    [tool/] extraction (audit §7.7 sub-gap 2). *)
let materialize_sandbox_workspace ~(sandbox : string) ~(target : string) : int =
  rm_rf target;
  mkdir_p target;
  let cmd =
    Printf.sprintf
      "rsync -a --exclude=_build --exclude=__pycache__ \
       --exclude='python_cext/build' \
       --exclude='python_cext/tiny_cext.egg-info' \
       --exclude='c/build/CMakeFiles' --exclude='c/build/CMakeCache.txt' \
       --exclude='c/build/cmake_install.cmake' --exclude='c/build/Makefile' \
       '%s/' '%s/'"
      sandbox target
  in
  let _ = run_shell cmd in
  Stdlib.(let oc = open_out (target ^ "/dune-project") in
          output_string oc "(lang dune 3.10)\n";
          close_out oc);
  if run_shell "command -v patchelf >/dev/null 2>&1" = 0 then begin
    let cext_dir = target ^ "/python_cext/tiny_cext" in
    if Stdlib.Sys.file_exists cext_dir then
      Stdlib.Sys.readdir cext_dir
      |> Array.iter ~f:(fun name ->
        if String.is_prefix name ~prefix:"_native.cpython-"
        && String.is_suffix name ~suffix:".so" then
          let _ =
            run_shell (Printf.sprintf
                         "patchelf --remove-rpath '%s/%s' 2>/dev/null"
                         cext_dir name) in ())
  end;
  let ic = Unix.open_process_in
             (Printf.sprintf "find '%s' -type f -o -type l 2>/dev/null | wc -l"
                target)
  in
  let n = try Int.of_string (String.strip (Stdlib.input_line ic))
          with _ -> 0 in
  let _ = Unix.close_process_in ic in
  n

let bool_json b = `String (if b then "ok" else "fail")

(** Prepare one scenario: sandbox setup, apply perturbation, build,
    run inspectors, compute deltas, write [confirm_ill.json],
    materialise workspace. *)
let run_prepare ~(name : string) : unit =
  if not (Stdlib.Sys.file_exists baseline_inspect) then
    prep_fail "no baseline cache at %s — run `tiny baseline` first"
      baseline_inspect;
  let entry =
    match Canary_tiny_scenario.find_by_name name with
    | Some e -> e
    | None -> prep_fail "unknown scenario: %s" name
  in
  let recipe = entry.recipe in
  let sandbox = scen_sandbox_of ~name in
  let inspect_dir = scen_inspect_of ~name in
  let workspace = scen_workspace_of ~name in
  prep_info "%s: copy live tree -> sandbox" name;
  if not (copy_live_to_sandbox ~sandbox) then prep_fail "sandbox copy failed";
  prep_info "%s: install baseline cext -> sandbox" name;
  if not (install_baseline_cext ~sandbox) then
    prep_fail "baseline cext install failed";
  (match recipe.perturbation with
   | Some (Patch { patch_file; _ }) ->
     prep_info "%s: apply patch %s" name patch_file;
     if not (apply_patch ~sandbox ~patch_file) then
       prep_fail "patch application failed"
   | _ -> ());
  let paths = sandbox_paths ~sandbox in
  let native_ok = build_c_lib ~paths () in
  let ocaml_ok  = if native_ok then build_ocaml_binding ~paths () else false in
  (match recipe.perturbation with
   | Some (Soname_bump { from_so; to_so }) ->
     prep_info "%s: apply soname bump %s -> %s" name from_so to_so;
     let _ = apply_soname_bump ~sandbox ~from_so ~to_so in ()
   | _ -> ());
  let build_status = `Assoc [
    "native", bool_json native_ok;
    "ocaml",  bool_json ocaml_ok;
  ] in
  mkdir_p inspect_dir;
  prep_info "%s: run inspectors" name;
  let perturbed : (string * Yojson.Basic.t option) list =
    List.map (inspectors ~paths) ~f:(fun (alias, fn) ->
      let j = fn () in
      (match j with
       | Some jj ->
         save_json (Printf.sprintf "%s/%s.json" inspect_dir alias) jj
       | None -> ());
      alias, j)
  in
  let baseline_of alias =
    let path = Printf.sprintf "%s/%s.json" baseline_inspect alias in
    if Stdlib.Sys.file_exists path
    then Some (Yojson.Basic.from_file path)
    else None
  in
  let deltas =
    List.filter_map perturbed ~f:(fun (alias, p) ->
      match surface_delta (baseline_of alias) p with
      | Some d -> Some (alias, d)
      | None -> None)
  in
  let confirm = confirm_of ~entry ~build_status ~deltas in
  save_json (scen_cache_of ~name ^ "/confirm_ill.json") confirm;
  prep_info "%s: materialize workspace" name;
  let ws_count = materialize_sandbox_workspace ~sandbox ~target:workspace in
  prep_info "%s: build native=%s ocaml=%s; deltas on %s; workspace %d files"
    name
    (if native_ok then "ok" else "fail")
    (if ocaml_ok then "ok" else "fail")
    (match List.map deltas ~f:fst with
     | [] -> "(none)"
     | xs -> String.concat ~sep:"," xs)
    ws_count

(** Run [prepare] for every scenario in insertion order. Auto-runs
    baseline first if the cache is missing. Exits non-zero if any
    scenario failed. *)
let run_prepare_all () : unit =
  if not (Stdlib.Sys.file_exists baseline_inspect) then begin
    prep_info "no baseline cache; running baseline first";
    run_baseline ()
  end;
  let failed = ref [] in
  List.iter Canary_tiny_scenario.entries ~f:(fun e ->
    try run_prepare ~name:e.scenario.name
    with _ -> failed := e.scenario.name :: !failed);
  match !failed with
  | [] -> prep_info "prepare-all: %d scenarios ok"
            (List.length Canary_tiny_scenario.entries)
  | xs ->
    prep_warn "prepare-all: %d failures: %s"
      (List.length xs) (String.concat ~sep:", " (List.rev xs));
    Stdlib.exit 1

(** Print the cached [confirm_ill.json] for [name] to stdout, or
    error if the cache doesn't exist. *)
let confirm ~(name : string) : unit =
  let path = scen_cache_of ~name ^ "/confirm_ill.json" in
  if not (Stdlib.Sys.file_exists path) then begin
    Stdlib.prerr_endline
      (Printf.sprintf
         "confirm: no cache for %S; run `tiny prepare %s` first"
         name name);
    Stdlib.exit 1
  end;
  let ic = Stdlib.open_in path in
  (try
     while true do
       Stdlib.print_endline (Stdlib.input_line ic)
     done
   with End_of_file -> ());
  Stdlib.close_in ic

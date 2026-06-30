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

let tiny_root          = "canary/examples/tiny"
let c_build            = tiny_root ^ "/c/build"
let cache              = tiny_root ^ "/scenarios/_cache"
let baseline_cache     = cache ^ "/baseline"
let baseline_inspect   = baseline_cache ^ "/inspect"
let baseline_workspace = baseline_cache ^ "/workspace"
let scripts            = "canary/scripts"
let ocaml_build_dir    = "_build/default/canary/examples/tiny/ocaml"

(* ---------- subprocess helpers ---------- *)

let warn fmt = Stdlib.Printf.ksprintf (fun s -> Stdlib.prerr_endline ("baseline: " ^ s)) fmt
let info fmt = Stdlib.Printf.ksprintf (fun s -> Stdlib.prerr_endline ("baseline: " ^ s)) fmt
let fail fmt = Stdlib.Printf.ksprintf (fun s -> Stdlib.prerr_endline ("baseline: " ^ s); Stdlib.exit 1) fmt

(** Run a shell command; return its exit code. stdout/stderr go to
    the inherited fds. *)
let run_shell (cmd : string) : int =
  Stdlib.Sys.command cmd

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

(* ---------- builds ---------- *)

let build_native () : bool =
  info "build native (cmake)";
  run_shell (Printf.sprintf "cmake --build '%s' >/dev/null 2>&1" c_build) = 0

let build_ocaml () : bool =
  info "build ocaml (dune)";
  (* env -u clears INSIDE_DUNE / DUNE_* so a nested dune (parent
     'dune exec' may still hold a lock when this runs) doesn't refuse
     to start. Python harness avoided this because it wasn't invoked
     under dune exec; the OCaml port is, so the unset is required. *)
  let cmd =
    Printf.sprintf
      "cd '%s/ocaml' && env -u INSIDE_DUNE -u DUNE_BUILD_DIR -u DUNE_INSTRUMENT_WITH \
       LIBRARY_PATH='%s:%s' LD_RUN_PATH='%s:%s' \
       dune build tiny.cmxa libtiny_stubs.a >/dev/null 2>&1"
      tiny_root c_build (Option.value (Sys.getenv "LIBRARY_PATH") ~default:"")
      c_build (Option.value (Sys.getenv "LD_RUN_PATH") ~default:"")
  in
  run_shell cmd = 0

let build_python_cext () : bool =
  info "build python_cext (make)";
  run_shell (Printf.sprintf "cd '%s' && make python_cext >/dev/null 2>&1" tiny_root) = 0

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

let mkdir_p p =
  if not (Stdlib.Sys.file_exists p) then
    let _ = run_shell (Printf.sprintf "mkdir -p '%s'" p) in ()

let rm_rf p =
  if Stdlib.Sys.file_exists p then
    let _ = run_shell (Printf.sprintf "rm -rf '%s'" p) in ()

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

let run () : unit =
  mkdir_p baseline_inspect;
  info "ensuring native + bindings are built";
  if not (build_native ()) then fail "C build failed";
  if not (build_ocaml ()) then fail "OCaml build failed";
  if not (build_python_cext ()) then fail "Python cext build failed";
  List.iter inspectors ~f:(fun (alias, fn) ->
    match fn () with
    | None -> warn "WARN %s produced no JSON" alias
    | Some j ->
      let path = Printf.sprintf "%s/%s.json" baseline_inspect alias in
      save_json path j;
      info "%s -> %s" alias path);
  let n = materialize_workspace () in
  info "snapshot workspace (%d files)" n

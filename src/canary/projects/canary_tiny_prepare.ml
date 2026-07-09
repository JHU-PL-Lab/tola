(** Tiny scenario prepare — OCaml port of
    [doc/_legacy_code/tiny_python_harness/scenarios.py (archived Phase E):cmd_prepare].

    Phase C.4 of the Python→OCaml migration
    ([doc/canary/worklog/tiny_migration.md] §9). Applies one
    scenario's perturbation in a hermetic sandbox
    ([_cache/<name>/sandbox/]), builds direct-compile artifacts
    there, runs the 7 inspectors on the sandbox, computes surface
    deltas vs the baseline cache, and materializes a workspace
    under [_cache/<name>/workspace/] that canary's tiny variants
    consume.

    Sandbox-build design (per [worklog/tiny_migration.md] §1b): the live
    tree is never mutated. Each scenario copies the live sources
    into its own sandbox; patches / rebuilds / SONAME bumps all
    happen inside the sandbox; positive-coverage scenarios still
    build so the workspace has valid artifacts. No revert needed.

    Cext handling: the sandbox does NOT rebuild
    [_native.cpython-*.so]. It copies the baseline-cached one
    ([_cache/baseline/artifacts/cext/]) instead. This preserves
    baseline's NEEDED entries, which is critical for scenarios
    like [symbol_version_floor] where the sandbox libtiny exports
    [TINY_2.0] but cext must keep referencing [TINY_1.0] for the
    version-mismatch detection to fire. *)

open Base
module B = Canary_tiny_baseline

let warn fmt =
  Stdlib.Printf.ksprintf
    (fun s -> Stdlib.prerr_endline ("prepare: " ^ s)) fmt
let info fmt =
  Stdlib.Printf.ksprintf
    (fun s -> Stdlib.prerr_endline ("prepare: " ^ s)) fmt
let fail fmt =
  Stdlib.Printf.ksprintf
    (fun s -> Stdlib.prerr_endline ("prepare: " ^ s); Stdlib.exit 1) fmt

let run_shell = B.run_shell
let mkdir_p = B.mkdir_p
let rm_rf = B.rm_rf
let capture_json = B.capture_json
let capture_line cmd =
  let ic = Unix.open_process_in (cmd ^ " 2>/dev/null") in
  let s = try Stdlib.input_line ic with End_of_file -> "" in
  let _ = Unix.close_process_in ic in
  String.strip s

let scen_cache_of ~name =
  Printf.sprintf "%s/%s" B.cache name
let scen_sandbox_of ~name = scen_cache_of ~name ^ "/sandbox"
let scen_inspect_of ~name = scen_cache_of ~name ^ "/inspect"
let scen_workspace_of ~name = scen_cache_of ~name ^ "/workspace"

let patches_dir = B.live_paths.tiny_root ^ "/scenarios/patches"

(* ---------- sandbox setup ---------- *)

(** Copy the live tiny tree into [sandbox]. Excludes the same
    fragments workspace-materialization uses, so the sandbox starts
    from a clean source-only state. *)
let copy_live_to_sandbox ~sandbox : bool =
  rm_rf sandbox;
  mkdir_p sandbox;
  (* cp -a preserves symlinks; --exclude drops build dirs. *)
  let cmd =
    Printf.sprintf
      "rsync -a --exclude=_build --exclude=__pycache__ \
       --exclude=scenarios/_cache --exclude='python_cext/build' \
       --exclude='python_cext/tiny_cext.egg-info' \
       --exclude='c/build/CMakeFiles' --exclude='c/build/CMakeCache.txt' \
       --exclude='c/build/cmake_install.cmake' --exclude='c/build/Makefile' \
       '%s/' '%s/'"
      B.live_paths.tiny_root sandbox
  in
  run_shell cmd = 0

(** Copy the baseline cext .so into the sandbox. Required for
    scenarios where cext's NEEDED must reflect the baseline lib
    (e.g. [symbol_version_floor]). *)
let install_baseline_cext ~sandbox : bool =
  let src_dir = B.baseline_cext in
  let dst_dir = sandbox ^ "/python_cext/tiny_cext" in
  if not (Stdlib.Sys.file_exists src_dir) then begin
    warn "baseline cext not found at %s; run baseline first" src_dir;
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
    warn "patch file missing: %s" full_patch; false
  end
  else
    run_shell
      (Printf.sprintf "cd '%s' && patch -p1 < '%s/%s' > /dev/null"
         sandbox
         (capture_line (Printf.sprintf "readlink -f %s" patches_dir))
         patch_file) = 0

(** SONAME bump: rename [libtiny.so.1.0] → [libtiny.so.2.0], drop
    the old symlinks, add new ones, rewrite the SONAME via patchelf.
    Runs AFTER the C library is built in the sandbox. *)
let apply_soname_bump ~sandbox ~from_so:_ ~to_so : bool =
  let c_build = sandbox ^ "/c/build" in
  (* to_so is like "libtiny.so.2.0"; derive the .so.N part. *)
  let major_so =
    match String.chop_suffix to_so ~suffix:".0" with
    | Some s -> s
    | None -> to_so
  in
  let steps = [
    (* Rename the concrete file. *)
    Printf.sprintf "mv '%s/libtiny.so.1.0' '%s/%s'" c_build c_build to_so;
    (* Drop old symlinks. *)
    Printf.sprintf "rm -f '%s/libtiny.so' '%s/libtiny.so.1'" c_build c_build;
    (* Recreate symlinks pointing at the new major. *)
    Printf.sprintf "ln -sf '%s' '%s/%s'" to_so c_build major_so;
    Printf.sprintf "ln -sf '%s' '%s/libtiny.so'" major_so c_build;
    (* Patch the SONAME embedded in the file. *)
    Printf.sprintf "patchelf --set-soname '%s' '%s/%s' 2>/dev/null || true"
      major_so c_build to_so;
  ] in
  List.for_all steps ~f:(fun cmd -> run_shell cmd = 0)

(* ---------- direct-compile in sandbox ----------
   These mirror baseline's build_c_lib / build_ocaml_binding but with
   sandbox paths. cext is NOT rebuilt (see install_baseline_cext). *)

let build_c_lib_in ~sandbox : bool =
  let c_build = sandbox ^ "/c/build" in
  let c_include = sandbox ^ "/c/include" in
  info "compile C lib in sandbox";
  mkdir_p c_build;
  let steps = [
    Printf.sprintf "gcc -c -fPIC -I%s %s/c/src/tiny.c -o %s/tiny.o"
      c_include sandbox c_build;
    Printf.sprintf
      "gcc -shared -Wl,-soname,libtiny.so.1 \
       -Wl,--version-script=%s/c/tiny.map %s/tiny.o -o %s/libtiny.so.1.0"
      sandbox c_build c_build;
    Printf.sprintf "ln -sf libtiny.so.1.0 %s/libtiny.so.1" c_build;
    Printf.sprintf "ln -sf libtiny.so.1 %s/libtiny.so" c_build;
    Printf.sprintf "rm -f %s/tiny.o" c_build;
  ] in
  List.for_all steps ~f:(fun cmd -> run_shell (cmd ^ " 2>&1") = 0)

let build_ocaml_binding_in ~sandbox : bool =
  let c_build = sandbox ^ "/c/build" in
  let c_include = sandbox ^ "/c/include" in
  let ocaml_src = sandbox ^ "/ocaml" in
  let ocaml_out = sandbox ^ "/_build/default/canary/examples/tiny/ocaml" in
  info "compile OCaml binding in sandbox";
  mkdir_p ocaml_out;
  let ocaml_where = capture_line "ocamlc -where" in
  if String.is_empty ocaml_where then begin
    warn "ocamlc -where returned empty"; false
  end
  else
    let cmi src target =
      Printf.sprintf
        "ocamlfind ocamlopt -bin-annot -I %s -c %s/%s -o %s/%s"
        ocaml_out ocaml_src src ocaml_out target
    in
    (* Ensure the sandbox tiny_stubs.c is on disk before invoking cc. *)
    let steps = [
      cmi "tiny_raw.mli" "tiny_raw.cmi";
      cmi "tiny_raw.ml"  "tiny_raw.cmx";
      cmi "tiny.mli"     "tiny.cmi";
      cmi "tiny.ml"      "tiny.cmx";
      Printf.sprintf
        "gcc -c -fPIC -I%s -I%s %s/tiny_stubs.c -o %s/tiny_stubs.o"
        ocaml_where c_include ocaml_src ocaml_out;
      Printf.sprintf
        "ar rcs %s/libtiny_stubs.a %s/tiny_stubs.o" ocaml_out ocaml_out;
      Printf.sprintf
        "ocamlfind ocamlopt -a %s/tiny_raw.cmx %s/tiny.cmx \
         -cclib -ltiny -cclib -ltiny_stubs -o %s/tiny.cmxa"
        ocaml_out ocaml_out ocaml_out;
    ] in
    (* Silence per-scenario noise but capture failures. *)
    let ok = List.for_all steps ~f:(fun cmd ->
      run_shell (cmd ^ " > /dev/null 2>&1") = 0)
    in
    let _ = c_build in (* not used at compile time; recorded for symmetry *)
    ok

(* ---------- inspectors in sandbox ---------- *)

let glob_first ~root ~pattern =
  let cmd = Printf.sprintf "find '%s' -name '%s' 2>/dev/null | head -1" root pattern in
  let ic = Unix.open_process_in cmd in
  let r = try Some (Stdlib.input_line ic) with End_of_file -> None in
  let _ = Unix.close_process_in ic in
  match r with
  | Some s when not (String.is_empty (String.strip s)) -> Some (String.strip s)
  | _ -> None

let inspect_n4 ~sandbox =
  let c_build = sandbox ^ "/c/build" in
  let so = c_build ^ "/libtiny.so.1" in
  let so =
    if Stdlib.Sys.file_exists so then so
    else Option.value (glob_first ~root:c_build ~pattern:"libtiny.so.*.0")
           ~default:so
  in
  if not (Stdlib.Sys.file_exists so) then None
  else
    capture_json
      (Printf.sprintf
         "nm -D '%s' | python3 '%s/inspect_native.py' \
          --path '%s' --prefixes tiny_ --elf --emit-symbols"
         so B.scripts so)

let inspect_bo4 ~sandbox =
  let mli = sandbox ^ "/ocaml/tiny.mli" in
  if not (Stdlib.Sys.file_exists mli) then None
  else
    capture_json
      (Printf.sprintf "python3 '%s/inspect_binding.py' --kind mli --path '%s'"
         B.scripts mli)

let inspect_bo6 ~sandbox =
  let ocaml_out = sandbox ^ "/_build/default/canary/examples/tiny/ocaml" in
  match glob_first ~root:ocaml_out ~pattern:"tiny.cmxa" with
  | None -> None
  | Some cmxa ->
    capture_json (Printf.sprintf "python3 '%s/inspect_ocaml.py' --path '%s'"
                    B.scripts cmxa)

let inspect_bo7 ~sandbox =
  let ocaml_out = sandbox ^ "/_build/default/canary/examples/tiny/ocaml" in
  match glob_first ~root:ocaml_out ~pattern:"libtiny_stubs*.a" with
  | None -> None
  | Some stub_a ->
    capture_json
      (Printf.sprintf
         "python3 '%s/inspect_binding.py' --kind stub --path '%s' --prefix tiny_"
         B.scripts stub_a)

let inspect_bpc2 ~sandbox =
  let c_build = sandbox ^ "/c/build" in
  capture_json
    (Printf.sprintf
       "PYTHONPATH='%s/python_ctypes' LD_LIBRARY_PATH='%s' \
        python3 '%s/inspect_python.py' --pkg tiny_ctypes"
       sandbox c_build B.scripts)

let inspect_bpe2 ~sandbox =
  let c_build = sandbox ^ "/c/build" in
  capture_json
    (Printf.sprintf
       "PYTHONPATH='%s/python_cext' LD_LIBRARY_PATH='%s' \
        python3 '%s/inspect_python.py' --pkg tiny_cext"
       sandbox c_build B.scripts)

let inspect_bpe3 ~sandbox =
  let cext_dir = sandbox ^ "/python_cext/tiny_cext" in
  match glob_first ~root:cext_dir ~pattern:"_native.cpython-*.so" with
  | None -> None
  | Some so ->
    capture_json
      (Printf.sprintf
         "nm -u '%s' | awk '/^[[:space:]]*U /{print $NF}' | sort -u | \
          python3 -c \"import json,sys; \
          syms=[l.strip() for l in sys.stdin if l.strip() and l.strip().startswith('tiny_')]; \
          json.dump({'kind':'c_stub','path':'%s','counts':{'required':len(syms)},'requires':sorted(syms)}, sys.stdout)\""
         so so)

let inspectors ~sandbox : (string * (unit -> Yojson.Basic.t option)) list = [
  "n4",   (fun () -> inspect_n4 ~sandbox);
  "bo4",  (fun () -> inspect_bo4 ~sandbox);
  "bo6",  (fun () -> inspect_bo6 ~sandbox);
  "bo7",  (fun () -> inspect_bo7 ~sandbox);
  "bpc2", (fun () -> inspect_bpc2 ~sandbox);
  "bpe2", (fun () -> inspect_bpe2 ~sandbox);
  "bpe3", (fun () -> inspect_bpe3 ~sandbox);
]

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

(** Compute delta between baseline and perturbed inspector JSONs.
    Returns None if no delta; Some assoc otherwise. Mirrors
    scenarios.py:_surface_delta. *)
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

(* ---------- workspace materialization from sandbox ---------- *)

(** Copy the sandbox into workspace/, excluding build fragments.
    Mirrors baseline.materialize_workspace but reads from sandbox
    instead of the live tree. Also adds dune-project + strips cext
    RUNPATH + ensures libtiny.so symlink. *)
let materialize_workspace ~(sandbox : string) ~(target : string) : int =
  rm_rf target;
  mkdir_p target;
  (* rsync copies with symlink preservation, excludes _build/__pycache__.
     Note we DO include the sandbox's c/build/libtiny.so* files which
     canary variants need at runtime. *)
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
  (* Minimal dune-project at workspace root. *)
  Stdlib.(let oc = open_out (target ^ "/dune-project") in
          output_string oc "(lang dune 3.10)\n";
          close_out oc);
  (* Strip RUNPATH from the cext .so if patchelf is available. *)
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
  (* Count files. *)
  let ic = Unix.open_process_in
             (Printf.sprintf "find '%s' -type f -o -type l 2>/dev/null | wc -l"
                target)
  in
  let n = try Int.of_string (String.strip (Stdlib.input_line ic))
          with _ -> 0 in
  let _ = Unix.close_process_in ic in
  n

let save_json path (j : Yojson.Basic.t) =
  let s = Yojson.Basic.pretty_to_string j in
  Stdlib.(let oc = open_out path in
          output_string oc s;
          output_char oc '\n';
          close_out oc)

let bool_json b = `String (if b then "ok" else "fail")

let run ~(name : string) : unit =
  if not (Stdlib.Sys.file_exists B.baseline_inspect) then
    fail "no baseline cache at %s — run `tiny-scenarios baseline` first"
      B.baseline_inspect;
  let entry =
    match Canary_tiny_scenario.find_by_name name with
    | Some e -> e
    | None -> fail "unknown scenario: %s" name
  in
  let recipe = entry.recipe in
  let sandbox = scen_sandbox_of ~name in
  let inspect_dir = scen_inspect_of ~name in
  let workspace = scen_workspace_of ~name in
  info "%s: copy live tree -> sandbox" name;
  if not (copy_live_to_sandbox ~sandbox) then fail "sandbox copy failed";
  info "%s: install baseline cext -> sandbox" name;
  if not (install_baseline_cext ~sandbox) then
    fail "baseline cext install failed";
  (* Apply source-side patch BEFORE build so it flows into artifacts. *)
  (match recipe.perturbation with
   | Some (Patch { patch_file; _ }) ->
     info "%s: apply patch %s" name patch_file;
     if not (apply_patch ~sandbox ~patch_file) then
       fail "patch application failed"
   | _ -> ());
  (* Build C lib + OCaml binding in sandbox. cext is NOT rebuilt —
     it was copied from baseline above. *)
  let native_ok = build_c_lib_in ~sandbox in
  let ocaml_ok  = if native_ok then build_ocaml_binding_in ~sandbox else false in
  (* Apply SONAME bump AFTER build (mutates the built .so). *)
  (match recipe.perturbation with
   | Some (Soname_bump { from_so; to_so }) ->
     info "%s: apply soname bump %s -> %s" name from_so to_so;
     let _ = apply_soname_bump ~sandbox ~from_so ~to_so in ()
   | _ -> ());
  let build_status = `Assoc [
    "native", bool_json native_ok;
    "ocaml",  bool_json ocaml_ok;
  ] in
  (* Run inspectors on the perturbed sandbox. *)
  mkdir_p inspect_dir;
  info "%s: run inspectors" name;
  let perturbed : (string * Yojson.Basic.t option) list =
    List.map (inspectors ~sandbox) ~f:(fun (alias, fn) ->
      let j = fn () in
      (match j with
       | Some jj ->
         save_json (Printf.sprintf "%s/%s.json" inspect_dir alias) jj
       | None -> ());
      alias, j)
  in
  (* Load baseline inspectors + compute deltas. *)
  let baseline_of alias =
    let path = Printf.sprintf "%s/%s.json" B.baseline_inspect alias in
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
  info "%s: materialize workspace" name;
  let ws_count = materialize_workspace ~sandbox ~target:workspace in
  info "%s: build native=%s ocaml=%s; deltas on %s; workspace %d files"
    name
    (if native_ok then "ok" else "fail")
    (if ocaml_ok then "ok" else "fail")
    (match List.map deltas ~f:fst with
     | [] -> "(none)"
     | xs -> String.concat ~sep:"," xs)
    ws_count

(** Run [prepare] for every scenario in insertion order. If the
    baseline cache is missing, auto-runs baseline first (matches
    Python [cmd_prepare_all]). Continues past individual failures;
    exits non-zero if any scenario failed. *)
let run_all () : unit =
  if not (Stdlib.Sys.file_exists B.baseline_inspect) then begin
    info "no baseline cache; running baseline first";
    B.run ()
  end;
  let failed = ref [] in
  List.iter Canary_tiny_scenario.entries ~f:(fun e ->
    try run ~name:e.scenario.name
    with _ -> failed := e.scenario.name :: !failed);
  match !failed with
  | [] -> info "prepare-all: %d scenarios ok"
            (List.length Canary_tiny_scenario.entries)
  | xs ->
    warn "prepare-all: %d failures: %s"
      (List.length xs) (String.concat ~sep:", " (List.rev xs));
    Stdlib.exit 1

(** Print the cached [confirm_ill.json] for [name] to stdout, or
    error if the cache doesn't exist. Mirrors Python [cmd_confirm]. *)
let confirm ~(name : string) : unit =
  let path = scen_cache_of ~name ^ "/confirm_ill.json" in
  if not (Stdlib.Sys.file_exists path) then begin
    Stdlib.prerr_endline
      (Printf.sprintf
         "confirm: no cache for %S; run `tiny-scenarios prepare %s` first"
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

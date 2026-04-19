(** Run cmake -P on cmake scripts and cmake -S -B for configure mode.
    Used for conf-run level validation: compile yelu → cmake text → cmake → check output. *)

type run_result = {
  exit_code : int;
  stdout : string;
  stderr : string;
}

type configure_result = {
  run   : run_result;
  cache : (string * string) list;  (* variable name → value, type stripped *)
}

let read_all ch =
  let buf = Buffer.create 4096 in
  let tmp = Bytes.create 4096 in
  let rec loop () =
    match input ch tmp 0 4096 with
    | 0 -> ()
    | n ->
      Buffer.add_string buf (Bytes.sub_string tmp 0 n);
      loop ()
    | exception End_of_file -> ()
  in
  loop ();
  Buffer.contents buf

let make_env extra =
  if extra = [] then Unix.environment ()
  else
    let extra_keys = List.map (fun (k, _) -> k) extra in
    let base = Array.to_list (Unix.environment ())
      |> List.filter (fun entry ->
          let key = match String.index_opt entry '=' with
            | Some i -> String.sub entry 0 i
            | None -> entry in
          not (List.mem key extra_keys))
    in
    Array.of_list (base @ List.map (fun (k, v) -> k ^ "=" ^ v) extra)

let run_script_file ?(env = []) ?(flags = []) path =
  let flags_str = match flags with [] -> "" | fs -> String.concat " " fs ^ " " in
  let cmd = Printf.sprintf "cmake %s-P %s" flags_str (Filename.quote path) in
  let stdout_ch, stdin_ch, stderr_ch =
    Unix.open_process_full cmd (make_env env)
  in
  close_out stdin_ch;
  let stdout = read_all stdout_ch in
  let stderr = read_all stderr_ch in
  let status = Unix.close_process_full (stdout_ch, stdin_ch, stderr_ch) in
  let exit_code =
    match status with
    | Unix.WEXITED n -> n
    | Unix.WSIGNALED n -> 128 + n
    | Unix.WSTOPPED n -> 128 + n
  in
  { exit_code; stdout; stderr }

let check_exit expected result =
  if result.exit_code <> expected then
    Alcotest.failf "exit %d, expected %d\nstderr:\n%s" result.exit_code expected result.stderr

let check_stderr_matches pattern result =
  let re = Re.Posix.compile_pat pattern in
  if not (Re.execp re result.stderr) then
    Alcotest.failf "stderr did not match pattern %S\ngot:\n%s" pattern result.stderr

let check_stdout_matches pattern result =
  let re = Re.Posix.compile_pat pattern in
  if not (Re.execp re result.stdout) then
    Alcotest.failf "stdout did not match pattern %S\ngot:\n%s" pattern result.stdout

let run_script ?(env = []) ?(flags = []) cmake_text =
  let tmp = Filename.temp_file "yelu_" ".cmake" in
  let cleanup () = (try Sys.remove tmp with _ -> ()) in
  match
    let oc = open_out tmp in
    output_string oc cmake_text;
    close_out oc;
    run_script_file ~env ~flags tmp
  with
  | result -> cleanup (); result
  | exception e -> cleanup (); raise e

(* Parse CMakeCache.txt into (name, value) pairs. Lines look like:
     VAR_NAME:TYPE=value
   Comment lines start with # or //; blank lines are skipped. *)
let parse_cache path =
  let ic = open_in path in
  let entries = ref [] in
  (try
    while true do
      let line = input_line ic in
      let line = String.trim line in
      if line <> "" && line.[0] <> '#' && not (String.length line >= 2 && line.[0] = '/' && line.[1] = '/') then
        (* find ':' for type separator, then '=' for value *)
        match String.index_opt line ':' with
        | None -> ()
        | Some colon ->
          let name = String.sub line 0 colon in
          let rest = String.sub line (colon + 1) (String.length line - colon - 1) in
          (match String.index_opt rest '=' with
           | None -> ()
           | Some eq ->
             let value = String.sub rest (eq + 1) (String.length rest - eq - 1) in
             entries := (name, value) :: !entries)
    done
  with End_of_file -> ());
  close_in ic;
  List.rev !entries

let run_configure ?(cmake_min = "3.20") ?(files = []) ?(languages = ["NONE"]) cmake_text =
  (* Wrap bare cmake text in a minimal project() if it has no project() call *)
  let has_project =
    let re = Re.(compile (seq [str "project"; rep (alt [char ' '; char '\t']); char '('])) in
    Re.execp re cmake_text in
  let full_text =
    if has_project then cmake_text
    else
      let langs = String.concat " " languages in
      Printf.sprintf "cmake_minimum_required(VERSION %s)\nproject(_yelu_test %s)\n%s" cmake_min langs cmake_text
  in
  let tmpdir = Filename.temp_file "yelu_conf_" "" in
  Sys.remove tmpdir;
  Unix.mkdir tmpdir 0o700;
  let build = Filename.concat tmpdir "_build" in
  let cleanup () =
    let rec rm path =
      if Sys.is_directory path then begin
        Array.iter (fun e -> rm (Filename.concat path e)) (Sys.readdir path);
        Unix.rmdir path
      end else Sys.remove path
    in
    (try rm tmpdir with _ -> ())
  in
  match
    let cmake_file = Filename.concat tmpdir "CMakeLists.txt" in
    let oc = open_out cmake_file in
    output_string oc full_text;
    close_out oc;
    List.iter (fun (name, content) ->
      let path = Filename.concat tmpdir name in
      let oc = open_out path in
      output_string oc content;
      close_out oc) files;
    let cmd = Printf.sprintf "cmake -S %s -B %s" (Filename.quote tmpdir) (Filename.quote build) in
    let stdout_ch, stdin_ch, stderr_ch = Unix.open_process_full cmd (Unix.environment ()) in
    close_out stdin_ch;
    let stdout = read_all stdout_ch in
    let stderr = read_all stderr_ch in
    let status = Unix.close_process_full (stdout_ch, stdin_ch, stderr_ch) in
    let exit_code = match status with
      | Unix.WEXITED n -> n | Unix.WSIGNALED n -> 128 + n | Unix.WSTOPPED n -> 128 + n
    in
    let cache_path = Filename.concat build "CMakeCache.txt" in
    let cache = if Sys.file_exists cache_path then parse_cache cache_path else [] in
    { run = { exit_code; stdout; stderr }; cache }
  with
  | result -> cleanup (); result
  | exception e -> cleanup (); raise e

let cache_get name result =
  List.assoc_opt name result.cache

let check_cache name expected result =
  match cache_get name result with
  | None -> Alcotest.failf "cache variable %S not found" name
  | Some v ->
    if v <> expected then
      Alcotest.failf "cache[%S]: expected %S, got %S" name expected v

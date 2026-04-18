(** Run cmake -P on cmake scripts and capture results.
    Used for conf-run level validation: compile yelu → cmake text → cmake -P → check output. *)

type run_result = {
  exit_code : int;
  stdout : string;
  stderr : string;
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

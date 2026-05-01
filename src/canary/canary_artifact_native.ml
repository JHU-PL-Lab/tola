open Base

(* Native library artifact ops.
   Handles .so / .dylib / .a formats. Uses nm for symbol inspection.
   Platform detection lives here because it currently only affects nm flags
   (-g on macOS, -D on Linux) and native lib filename conventions. *)

(* ── Platform detection ── *)

let platform =
  let ic = Unix.open_process_in "uname -s 2>/dev/null" in
  let s = try String.strip (Stdlib.input_line ic) with End_of_file -> "" in
  ignore (Unix.close_process_in ic);
  s

let is_macos = String.equal platform "Darwin"

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
let native_lib_probe_cmd ~lib ~prefix ~output_dir =
  let nm_flag = if is_macos then "-g" else "-D" in
  [%string
    {|COUNT=$(nm %{nm_flag} "%{lib}" 2>/dev/null | grep -v ' U ' | grep -c '%{prefix}' || echo 0)
printf '%{prefix} symbols exported: %s\n' "$COUNT" | tee %{output_dir}/probe.log
test "$COUNT" -gt 0|}]

(* Emit compact artifact summary as summary.json.
   Dumps total symbol count, per-prefix counts, versioned-deps map (L1b),
   and a watchlist presence check. See doc/canary/design/api_interface.md. *)
(* Note: [lib] is embedded in double quotes so shell variable expansion works
   (e.g., passing "$LIB_Z3" from a resolve snippet). Callers using literal
   paths get the usual behavior; paths with shell metacharacters or spaces
   need escaping at the call site. *)
let summary_cmd ~lib ?(prefixes = []) ?(watchlist = []) ~output_dir () =
  let nm_flag = if is_macos then "-g" else "-D" in
  (* On macOS, Mach-O nm prefixes every C symbol with `_`. Tell the parser
     to strip it; on Linux the symbol IS the C ABI name (no strip). *)
  let strip_flag = if is_macos then "--strip-leading-underscore " else "" in
  let script = "canary/scripts/summarize_native.py" in
  let prefixes_csv = String.concat ~sep:"," prefixes in
  let watchlist_csv = String.concat ~sep:"," watchlist in
  [%string
    {|nm %{nm_flag} "%{lib}" 2>/dev/null \
  | python3 %{script} %{strip_flag}--emit-symbols --path "%{lib}" --prefixes '%{prefixes_csv}' --watchlist '%{watchlist_csv}' \
  > %{output_dir}/summary.json|}]

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

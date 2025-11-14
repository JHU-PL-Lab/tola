open Base
open OpamStd.Sys

(* ldd output *)
type linked_dep = {
  name : string option;
  path : string option;
  addr : string option;
}

(* readelf output *)
type declared_dep = {
  needed : string list;
  rpath : string list;
  runpath : string list;
  soname : string option;
}

(* One dependency line from `otool -L` *)
type otool_dep = {
  path : string; (* dylib path: e.g. /usr/lib/libSystem.B.dylib or @rpath/xxx *)
  compat_version : string option;
  (* "compatibility version X.Y.Z" Interesting to find this *)
  current_version : string option; (* "current version A.B.C" *)
}

type otool_deps = otool_dep list

type binary_deps =
  | Elf of { declared_dep : declared_dep }
  | Macho of { otool_deps : otool_deps }

let elf_inspect_cmd : _ format4 =
  "readelf -d %s | grep -E 'RPATH|RUNPATH|SONAME|NEEDED'"

let otool_inspect_cmd : _ format4 = "otool -L %s"

(* let ldd_inspect_cmd = ("ldd %s " : _ format4) *)

let shared_ext = function
  | Linux -> "so"
  | Darwin -> "dylib"
  | Win32 -> "dll"
  | _ -> raise (Failure "Unsupported OS for shared library")

let is_shared_ext ext =
  match ext with "so" | "dylib" | "dll" -> true | _ -> false

let static_ext = function
  | Linux | Darwin -> "a"
  | Win32 -> "lib"
  | _ -> raise (Failure "Unsupported OS for static library")

let is_static_ext ext = match ext with "a" | "lib" -> true | _ -> false

(* TODO: only windows or dune forced an exe *)
let exe_ext = function Win32 -> "exe" | _ -> "out"
let is_exe_ext ext = match ext with "exe" | "out" -> true | _ -> false

(* ) 
  
let tool_symbol os =
  match os with
  | Linux -> "nm -D"
  | Darwin -> "nm -gU"
  | _ -> failwith "Unsupported OS for symbol tool" 
  *)

let tool_dep os =
  match os with
  | Linux -> "ldd"
  | Darwin -> "otool -L"
  | _ -> failwith "Unsupported OS for dependency tool"

let parse_readelf (s : string) : declared_dep =
  let lines = String.split_lines s in
  let needed = ref [] in
  let rpath = ref [] in
  let runpath = ref [] in
  let soname = ref None in

  let extract_bracket_payload (line : string) : string option =
    match (String.index line '[', String.rindex line ']') with
    | Some lb, Some rb when rb > lb ->
        Some (String.sub line ~pos:(lb + 1) ~len:(rb - lb - 1) |> String.strip)
    | _ -> None
  in
  let parse_bracket_payload line f =
    Option.iter (extract_bracket_payload line) ~f
  in
  List.iter lines ~f:(fun line ->
      let line = String.strip line in
      if String.is_substring line ~substring:"(NEEDED)" then
        parse_bracket_payload line (fun v -> needed := !needed @ [ v ])
      else if String.is_substring line ~substring:"(SONAME)" then
        parse_bracket_payload line (fun v -> soname := Some v)
      else if String.is_substring line ~substring:"(RPATH)" then
        parse_bracket_payload line (fun v ->
            rpath := !rpath @ String.split ~on:':' v)
      else if String.is_substring line ~substring:"(RUNPATH)" then
        parse_bracket_payload line (fun v ->
            runpath := !runpath @ String.split ~on:':' v)
      else ());

  { needed = !needed; rpath = !rpath; runpath = !runpath; soname = !soname }

let print_declared_dep (d : declared_dep) =
  Fmt.pr "SONAME=%a@." Fmt.(option string) d.soname;
  Fmt.pr "NEEDED=[%a]@." Fmt.(list ~sep:(any "; ") string) d.needed;
  Fmt.pr "RPATH=[%a]@." Fmt.(list ~sep:(any ": ") string) d.rpath;
  Fmt.pr "RUNPATH=[%a]@." Fmt.(list ~sep:(any ": ") string) d.runpath

let dump_readelf s = parse_readelf s |> print_declared_dep

let parse_ldd_line (line : string) : linked_dep option =
  let line = String.strip line in
  if String.is_empty line then None
  else
    let extract_addr_and_before s =
      match (String.rindex s '(', String.rindex s ')') with
      | None, None -> (None, String.strip s)
      | Some lparen, Some rparen when rparen > lparen ->
          let addr =
            String.sub s ~pos:(lparen + 1) ~len:(rparen - lparen - 1)
            |> String.strip
          in
          let before = String.sub s ~pos:0 ~len:lparen |> String.strip in
          (Some addr, before)
      | _, _ -> raise (Failure "Malformed line: unmatched parentheses")
    in
    match String.substr_index line ~pattern:"=>" with
    | Some idx ->
        (* case2: name => path(addr) *)
        let left = String.sub line ~pos:0 ~len:idx |> String.strip in
        let right =
          String.sub line ~pos:(idx + 2) ~len:(String.length line - idx - 2)
          |> String.strip
        in
        let addr_opt, right_before = extract_addr_and_before right in
        let path =
          let p = right_before in
          if String.( = ) (String.strip p) "not found" then None else Some p
        in
        (* Fmt.pr "case2: name=%s path=%s addr=%s@." left
            (Option.value path ~default:"<none>")
            (Option.value addr_opt ~default:"<none>"); *)
        Some { name = Some left; path; addr = addr_opt }
    | None ->
        (* case1 or case3: token(addr) *)
        let addr_opt, token = extract_addr_and_before line in
        if String.is_prefix token ~prefix:"/" then
          (* Fmt.pr "case1: path=%s addr=%s@." token
              (Option.value addr_opt ~default:"<none>"); *)
          Some { name = None; path = Some token; addr = addr_opt }
        else
          (* Fmt.pr "case3: name=%s addr=%s@." token
              (Option.value addr_opt ~default:"<none>"); *)
          Some { name = Some token; path = None; addr = addr_opt }

let parse_ldd (s : string) : linked_dep list =
  s |> String.split_on_chars ~on:[ '\n' ] |> List.filter_map ~f:parse_ldd_line

let print_ldd deps =
  List.iteri
    ~f:(fun i dep ->
      Fmt.pr "[LD][%d]name=%a; path=%a; addr=%a@." i (Fmt.option Fmt.string)
        dep.name (Fmt.option Fmt.string) dep.path (Fmt.option Fmt.string)
        dep.addr)
    deps

let dump_ldd result = parse_ldd result |> print_ldd

(* ---------- Parsing ---------- *)

open Core

let is_header_line (line : string) : bool =
  (* First line is "<file>:"; `otool -L` also echoes the file path with a trailing colon. *)
  let line = String.strip line in
  String.is_suffix line ~suffix:":"

let extract_between (s : string) (start_idx : int) (delims : char list) : string
    =
  (* Take substring starting at start_idx until the first delimiter in [delims] or end *)
  let len = String.length s in
  let rec find_stop i =
    if i >= len then len
    else if List.exists delims ~f:(Char.equal s.[i]) then i
    else find_stop (i + 1)
  in
  let stop = find_stop start_idx in
  String.sub s ~pos:start_idx ~len:(stop - start_idx) |> String.strip

let parse_versions_inside_parens (inside : string) :
    string option * string option =
  (* inside looks like: "compatibility version 1.0.0, current version 1292.60.1" *)
  let compat_pat = "compatibility version " in
  let current_pat = "current version " in
  let compat =
    match String.substr_index inside ~pattern:compat_pat with
    | None -> None
    | Some i ->
        let start = i + String.length compat_pat in
        Some (extract_between inside start [ ','; ')' ])
  in
  let current =
    match String.substr_index inside ~pattern:current_pat with
    | None -> None
    | Some i ->
        let start = i + String.length current_pat in
        Some (extract_between inside start [ ','; ')' ])
  in
  (compat, current)

let parse_otool_L_line (line : string) : otool_dep option =
  let line = String.strip line in
  if String.is_empty line || is_header_line line then None
  else
    (* Typical line:
         "/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1292.60.1)"
       or
         "@rpath/libfoo.dylib (compatibility version 1.2.3, current version 1.2.3)"
       Occasionally there might be no parens (rare); we handle that too. *)
    match String.index line '(' with
    | None ->
        Some { path = line; compat_version = None; current_version = None }
    | Some lp ->
        let rp =
          match String.rindex line ')' with
          | Some idx -> idx
          | None -> String.length line - 1
        in
        let path = String.sub line ~pos:0 ~len:lp |> String.strip in
        let inside =
          let pos = lp + 1 in
          let len = Int.max 0 (rp - pos) in
          String.sub line ~pos ~len |> String.strip
        in
        let compat_version, current_version =
          parse_versions_inside_parens inside
        in
        Some { path; compat_version; current_version }

let parse_otool_L_output (s : string) : otool_dep list =
  s |> String.split_lines |> List.filter_map ~f:parse_otool_L_line

(* ---------- Pretty printer (optional) ---------- *)

let pp_otool_dep (d : otool_dep) : unit =
  let cv = Option.value d.compat_version ~default:"<none>" in
  let cur = Option.value d.current_version ~default:"<none>" in
  Fmt.pr "path=%s; compat=%s; current=%s@." d.path cv cur

let print_otool_deps (deps : otool_dep list) : unit =
  List.iter deps ~f:pp_otool_dep

let dump_otool_L s = parse_otool_L_output s |> print_otool_deps

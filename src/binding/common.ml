open Base

(* See https://github.com/ocaml/opam/blob/master/src/state/opamSysPoll.ml 
For ELF parser: see
https://github.com/let-def/owee
https://github.com/ashay/owl

*)

module Target_triple = struct
  type os = Linux | MacOS | Windows | Bsd | Other_os of string

  type distro =
    | Debian
    | Ubuntu
    | Fedora
    | Arch
    | Alpine
    | MacOS_Brew
    | MacOS_Macports
    | Windows_MSYS
    | Windows_Mingw
    | Windows_Msvc
    | Unknown_distro of string

  type arch = X86_64 | Aarch64 | Armv7 | Riscv64 | Other_arch of string
  type t = { os : os; distro : distro; arch : arch }
end

module Shared_library = struct
  open OpamStd.Sys

  type t = { tag : string; path : string } [@@deriving show]

  let detect_os os =
    let name =
      match os with
      | Linux -> "Linux"
      | Unix -> "Unix"
      | Darwin -> "Darwin"
      | _ -> "Others"
    in
    Fmt.pr "Detected OS: %s@." name

  let ext os =
    match os with
    | Linux -> "so"
    | Darwin -> "dylib"
    | Win32 -> "dll"
    | _ -> raise (Failure "Unsupported OS for shared library")

  let tool_dep os =
    match os with
    | Linux -> "ldd"
    | Darwin -> "otool -L"
    | _ -> failwith "Unsupported OS for dependency tool"

  type dep = {
    name : string option;
    path : string option;
    addr : string option;
  }

  let parse_ldd_line (line : string) : dep option =
    (* New logic: detect arrows first. If line contains => it's case2 (name => path(addr)).
       Otherwise it's case1 or case3: token(addr), where token is either absolute path (case1) or a vdso/name (case3).
       We also print Fmt-based debug markers: case1/case2/case3. *)
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

  let parse_otool_output (s : string) : dep list =
    s |> String.split_on_chars ~on:[ '\n' ] |> List.filter_map ~f:parse_ldd_line

  let tool_symbol os =
    match os with
    | Linux -> "nm -D"
    | Darwin -> "nm -gU"
    | _ -> failwith "Unsupported OS for symbol tool"
end

let the_os = OpamStd.Sys.os ()

let run_tool target =
  let open Shared_library in
  let tool = Shared_library.tool_dep the_os in
  let cmd = Fmt.str "%s %s" tool target in
  let result = Tola_std.Std.Sys_util.run_and_capture cmd in
  Fmt.pr "Running command: %s@.Result:@.%s@." cmd result;
  let ldd_lines = Shared_library.parse_otool_output result in
  List.iteri
    ~f:(fun i dep ->
      Fmt.pr "[Dep %d]name=%a; path=%a; addr=%a@." i (Fmt.option Fmt.string)
        dep.name (Fmt.option Fmt.string) dep.path (Fmt.option Fmt.string)
        dep.addr)
    ldd_lines

let () =
  run_tool "~/.opam/5.3.0/lib/stublibs/libz3.so";
  run_tool "~/.opam/5.3.0/lib/stublibs/dllz3ml.so";
  ()
(* 
  let un = OpamStd.Sys.uname () in
  Fmt.pr "machine: %s; release: %s; sysname: %s@.\n" un.machine un.release
    un.sysname; 
  detect_os () ; *)
(* machine: x86_64; release: 5.15.167.4-microsoft-standard-WSL2; sysname: Linux 
  Detected OS: Linux
  *)

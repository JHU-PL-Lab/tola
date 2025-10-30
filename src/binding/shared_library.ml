open Base
open OpamStd.Sys

let tool_dep os =
  match os with
  | Linux -> "ldd"
  | Darwin -> "otool -L"
  | _ -> failwith "Unsupported OS for dependency tool"

(* ldd output *)
type linked_dep = {
  name : string option;
  path : string option;
  addr : string option;
}

type declared_dep = {
  needed : string list;
  rpath : string list;
  runpath : string list;
  soname : string option;
}

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

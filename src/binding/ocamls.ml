open Base

(* ================ 数据结构 ================ *)

type link_spec =
  | L_lib of string (* -lfoo             -> "foo" *)
  | L_Lpath of string (* -L/abs/dir        -> "/abs/dir" *)
  | L_other of string

type link_opt =
  | O_rpath of string list (* -Wl,-rpath,....  *)
  | O_flag of string

type extras = {
  c_object_files : link_spec list; (* From "Extra C object files:" *)
  c_options : link_opt list; (* From "Extra C options:" *)
  dlloader_libs : link_spec list;
      (* From "Extra dynamically-loaded libraries:" *)
}

let split_words (s : string) : string list =
  String.split s ~on:' '
  |> List.filter ~f:(fun w -> not (String.is_empty (String.strip w)))

let split_colons (s : string) : string list =
  String.split s ~on:':' |> List.map ~f:String.strip
  |> List.filter ~f:(fun x -> not (String.is_empty x))

let parse_libspec_token (tok : string) : link_spec =
  if String.is_prefix tok ~prefix:"-l" && String.length tok > 2 then
    L_lib (String.drop_prefix tok 2)
  else if String.is_prefix tok ~prefix:"-L" && String.length tok > 2 then
    L_Lpath (String.drop_prefix tok 2)
  else L_other tok

(* For "Extra C object files:" and "Extra dynamically-loaded libraries:" *)
let parse_libspec_list (payload : string) : link_spec list =
  split_words payload |> List.map ~f:parse_libspec_token

(* For "Extra C options:" 
   recognize -Wl,-rpath,<p1:p2:...>，and convert <...> to string list。 *)
let parse_c_options (payload : string) : link_opt list =
  let words = split_words payload in
  let rec loop acc = function
    | [] -> List.rev acc
    | w :: ws ->
        (* common case: all rpath in a word *)
        if String.is_prefix w ~prefix:"-Wl,-rpath," then
          let paths = String.drop_prefix w (String.length "-Wl,-rpath,") in
          let rps = split_colons paths in
          loop (O_rpath rps :: acc) ws
        else
          (* otherwise *)
          loop (O_flag w :: acc) ws
  in
  loop [] words

let parse_ocamlobjinfo_extras (s : string) : extras =
  let c_object_files = ref [] in
  let c_options = ref [] in
  let dlloader_libs = ref [] in

  let handle_line (line : string) =
    let line = String.strip line in
    match String.lsplit2 ~on:':' line with
    | None -> ()
    | Some (hdr, rest) ->
        let payload = String.strip rest in
        if String.is_prefix hdr ~prefix:"Extra C object files" then
          c_object_files := parse_libspec_list payload
        else if String.is_prefix hdr ~prefix:"Extra C options" then
          c_options := parse_c_options payload
        else if
          String.is_prefix hdr ~prefix:"Extra dynamically-loaded libraries"
        then dlloader_libs := parse_libspec_list payload
        else ()
  in

  String.split_lines s |> List.iter ~f:handle_line;
  {
    c_object_files = !c_object_files;
    c_options = !c_options;
    dlloader_libs = !dlloader_libs;
  }

let pp_link_spec fmt = function
  | L_lib name -> Fmt.pf fmt "-l%s" name
  | L_Lpath dir -> Fmt.pf fmt "-L%s" dir
  | L_other s -> Fmt.pf fmt "%s" s

let pp_link_opt ?(sep = Fmt.any ": ") fmt = function
  | O_rpath xs -> Fmt.pf fmt "-Wl,-rpath,[%a]" Fmt.(list ~sep string) xs
  | O_flag s -> Fmt.pf fmt "%s" s

let pp_extras ?(sep = Fmt.any ": ") fmt (e : extras) =
  Fmt.pf fmt "Extra C object files: [%a]@."
    Fmt.(list ~sep pp_link_spec)
    e.c_object_files;
  Fmt.pf fmt "Extra C options: [%a]@." Fmt.(list ~sep pp_link_opt) e.c_options;
  Fmt.pf fmt "Extra dynamically-loaded libraries: [%a]@."
    Fmt.(list ~sep pp_link_spec)
    e.dlloader_libs

let dump_extras s =
  s |> parse_ocamlobjinfo_extras |> Fmt.pr "%a" (pp_extras ~sep:(Fmt.any "; "))

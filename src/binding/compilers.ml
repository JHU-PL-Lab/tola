open Base

type link_spec =
  | L_lib of string (* -lfoo             -> "foo" *)
  | L_Lpath of string (* -L/abs/dir        -> "/abs/dir" *)
  | L_other of string

type link_opt =
  | O_rpath of string list (* -Wl,-rpath,....  *)
  | O_flag of string

let pp_link_spec fmt = function
  | L_lib name -> Fmt.pf fmt "-l%s" name
  | L_Lpath dir -> Fmt.pf fmt "-L%s" dir
  | L_other s -> Fmt.pf fmt "%s" s

let pp_link_opt ?(sep = Fmt.any ": ") fmt = function
  | O_rpath xs -> Fmt.pf fmt "-Wl,-rpath,[%a]" Fmt.(list ~sep string) xs
  | O_flag s -> Fmt.pf fmt "%s" s

let split_words (s : string) : string list =
  String.split s ~on:' '
  |> List.filter ~f:(fun w -> not (String.is_empty (String.strip w)))

let split_colons (s : string) : string list =
  String.split s ~on:':' |> List.map ~f:String.strip
  |> List.filter ~f:(fun x -> not (String.is_empty x))

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

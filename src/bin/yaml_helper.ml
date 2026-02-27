open Base
open Tola_std

let ensure_trailing_newline (s : string) =
  if String.is_suffix s ~suffix:"\n" then s else s ^ "\n"

let leading_spaces (s : string) =
  let rec loop i =
    if i >= String.length s then i
    else if Char.equal s.[i] ' ' then loop (i + 1)
    else i
  in
  loop 0

let placeholders_in_string (s : string) =
  let rec loop pos acc =
    match String.substr_index s ~pos ~pattern:"<<" with
    | None -> acc
    | Some start -> (
        let after = start + 2 in
        match String.substr_index s ~pos:after ~pattern:">>" with
        | None -> acc
        | Some stop ->
            let name = String.sub s ~pos:after ~len:(stop - after) in
            let acc = if String.is_empty name then acc else Set.add acc name in
            loop (stop + 2) acc)
  in
  loop 0 (Set.empty (module String))

let indent_lines ~indent (s : string) =
  String.split_lines s
  |> List.map ~f:(fun line -> indent ^ line)
  |> String.concat ~sep:"\n"

let replace_token_yaml_aware (yaml_s : string) ~(token : string) ~(value : string) =
  if not (String.is_substring value ~substring:"\n") then
    String.substr_replace_all yaml_s ~pattern:token ~with_:value
  else
    let lines = String.split_lines yaml_s in
    let lines' =
      List.concat_map lines ~f:(fun line ->
          match String.substr_index line ~pattern:token with
          | None -> [ line ]
          | Some tok_pos ->
              let before = String.prefix line tok_pos in
              let after =
                String.drop_prefix line (tok_pos + String.length token)
              in
              let before_stripped = String.rstrip before in
              if
                String.is_empty (String.strip after)
                && String.is_suffix before_stripped ~suffix:":"
              then
                let base_indent = leading_spaces line in
                let body_indent = String.make (base_indent + 2) ' ' in
                let key_line = before_stripped ^ " |" in
                let body = indent_lines ~indent:body_indent value in
                key_line :: String.split_lines body
              else if String.equal (String.strip line) token then
                let body_indent = String.make (leading_spaces line) ' ' in
                let body = indent_lines ~indent:body_indent value in
                String.split_lines body
              else [ String.substr_replace_all line ~pattern:token ~with_:value ])
    in
    String.concat ~sep:"\n" lines'

let get_rresult_exn = function Ok v -> v | Error (`Msg m) -> failwith m

let replace_in_yaml_file ?(strict = true) file_src file_dst from_to_lst =
  let yaml_s = read_file file_src in
  (if strict then
     let provided =
       Set.of_list (module String) (List.map from_to_lst ~f:(fun (k, _) -> k))
     in
     let used = placeholders_in_string yaml_s in
     let missing = Set.diff used provided in
     if not (Set.is_empty missing) then
       failwith
         (Fmt.str "Missing substitutions for: %s"
            (String.concat ~sep:", " (Set.to_list missing))));
  let yaml'_s =
    List.fold
      ~f:(fun acc (from, to_) ->
        let from = Fmt.str "<<%s>>" from in
        replace_token_yaml_aware acc ~token:from ~value:to_)
      ~init:yaml_s from_to_lst
  in
  let yaml'_s = ensure_trailing_newline yaml'_s in
  write_file file_dst yaml'_s;
  let _ = read_file file_dst |> Yaml.yaml_of_string |> get_rresult_exn in
  ()

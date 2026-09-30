open Base

(** The overview page's hand-written assets: its stylesheets and scripts,
    in [canary/overview/], read from the repository root, where
    [canary overview] writes the page. A file's final newline is not part
    of the asset. *)

let dir = "canary/overview"

(** HTML-escapes a text for an element or an attribute value. *)
let esc (s : string) : string =
  String.concat_map s ~f:(function
    | '&' -> "&amp;"
    | '<' -> "&lt;"
    | '>' -> "&gt;"
    | '"' -> "&quot;"
    | c -> String.of_char c)

let read (name : string) : string =
  let path = dir ^ "/" ^ name in
  match Stdlib.In_channel.with_open_bin path Stdlib.In_channel.input_all with
  | s -> Option.value (String.chop_suffix s ~suffix:"\n") ~default:s
  | exception Sys_error e ->
      failwith (e ^ " (the overview's assets are read from the repository root)")

(** A script asset, inlined between its tags. *)
let script (name : string) : string = "<script>\n" ^ read name ^ "\n</script>"

(** [template] with its [{{slot}}]s replaced by [values], in one pass over
    the template, so a value is inserted as it is. Every slot needs a value
    and every value a slot; [what] names the template in the failure. *)
let fill_text ~(what : string) (template : string) (values : (string * string) list) :
    string =
  let buf = Buffer.create (2 * String.length template) in
  let used = ref [] in
  let rec go pos =
    match String.substr_index template ~pos ~pattern:"{{" with
    | None -> Buffer.add_string buf (String.drop_prefix template pos)
    | Some i -> (
        Buffer.add_string buf (String.sub template ~pos ~len:(i - pos));
        match String.substr_index template ~pos:(i + 2) ~pattern:"}}" with
        | None -> failwith (what ^ ": a slot opened with {{ is never closed")
        | Some j ->
            let slot = String.sub template ~pos:(i + 2) ~len:(j - i - 2) in
            (match List.Assoc.find values slot ~equal:String.equal with
             | Some v -> Buffer.add_string buf v
             | None -> failwith (what ^ ": no value for {{" ^ slot ^ "}}"));
            used := slot :: !used;
            go (j + 2))
  in
  go 0;
  List.iter values ~f:(fun (k, _) ->
      if not (List.mem !used k ~equal:String.equal) then
        failwith (what ^ ": no slot {{" ^ k ^ "}} for a value"));
  Buffer.contents buf

(** A template asset, filled. *)
let fill (name : string) (values : (string * string) list) : string =
  fill_text ~what:(dir ^ "/" ^ name) (read name) values

(** The [{{slot}}]s a template asset names, in order. *)
let slots (name : string) : string list =
  let t = read name in
  let rec go pos acc =
    match String.substr_index t ~pos ~pattern:"{{" with
    | None -> List.rev acc
    | Some i -> (
        match String.substr_index t ~pos:(i + 2) ~pattern:"}}" with
        | None -> List.rev acc
        | Some j -> go (j + 2) (String.sub t ~pos:(i + 2) ~len:(j - i - 2) :: acc))
  in
  go 0 []

(** Where the page is written. *)
let docs_path = "docs/canary/overview.html"

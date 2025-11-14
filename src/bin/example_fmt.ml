open Core
open Fmt

let base_colors : color list =
  [ `Black; `Red; `Green; `Yellow; `Blue; `Magenta; `Cyan; `White ]

let string_of_color (c : color) : string =
  match c with
  | `Black -> "black"
  | `Red -> "red"
  | `Green -> "green"
  | `Yellow -> "yellow"
  | `Blue -> "blue"
  | `Magenta -> "magenta"
  | `Cyan -> "cyan"
  | `White -> "white"

(* color style *)
let color_styles (c : color) : (string * style) list =
  let name = string_of_color c in
  [
    (name, (c :> style));
    ("fg " ^ name, (`Fg c :> style));
    ("fg hi " ^ name, `Fg (`Hi c));
    ("bg " ^ name, (`Bg c :> style));
    ("bg hi " ^ name, `Bg (`Hi c));
  ]

(* non-color style *)
let non_color_styles : (string * style) list =
  [
    ("none", `None);
    ("bold", `Bold);
    ("faint", `Faint);
    ("italic", `Italic);
    ("underline", `Underline);
    ("reverse", `Reverse);
  ]

let demo_styles : (string * style) list =
  [ ("fg yellow", (`Fg `Yellow :> style)); ("bg red", (`Bg `Red :> style)) ]
  @
  (* remove `None` since it's less interesting in demo *)
  List.tl_exn non_color_styles

let styles ss pp = List.fold ss ~init:pp ~f:(fun acc s -> styled s acc)

let demo () =
  (* enable ansi color *)
  Fmt.set_style_renderer Fmt.stdout `Ansi_tty;

  List.iter non_color_styles ~f:(fun (name, st) ->
      Fmt.pr "%a@." (styled st string) name);
  Fmt.pr "@.";

  List.iter base_colors ~f:(fun c ->
      let styles = color_styles c in
      List.iter styles ~f:(fun (name, st) ->
          Fmt.pr "%a@." (styled st string) name);
      Fmt.pr "@.");

  Tola_std.all_sub_lists ~start:2 demo_styles
  |> List.iter ~f:(fun name_styles ->
      let names, sts = List.unzip name_styles in
      let name = String.concat ~sep:", " names in
      Fmt.pr "%a@." (styles sts string) name)

let () = demo ()

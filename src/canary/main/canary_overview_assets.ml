open Base

(** The overview page's hand-written assets: its stylesheets and scripts,
    in [canary/overview/], read from the repository root, where
    [canary overview] writes the page. A file's final newline is not part
    of the asset. *)

let dir = "canary/overview"

let read (name : string) : string =
  let path = dir ^ "/" ^ name in
  match Stdlib.In_channel.with_open_bin path Stdlib.In_channel.input_all with
  | s -> Option.value (String.chop_suffix s ~suffix:"\n") ~default:s
  | exception Sys_error e ->
      failwith (e ^ " (the overview's assets are read from the repository root)")

(** A script asset, inlined between its tags. *)
let script (name : string) : string = "<script>\n" ^ read name ^ "\n</script>"

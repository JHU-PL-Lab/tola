(** §0.4 of the overview page: every pin of [canary project-test], under
    the file it is written in, with the claim it holds and the boxes of
    Figure 1 it holds. The pins come in as data, from
    [Canary_tests.pin_files]: the test modules render this page, so the
    page cannot name them. *)

open Base

let esc = Canary_overview_assets.esc

type pin = { pn_name : string; pn_holds : string }

(** A test file: what its pins are about, its path, its pins in run order. *)
type file = { pf_subject : string; pf_path : string; pf_pins : pin list }

(** The boxes of Figure 1 the pins hold, in the figure's order. *)
let boxes_held (pins : pin list) : string list =
  List.filter_map Canary_overview_flow.boxes ~f:(fun b ->
      Option.some_if
        (List.exists pins ~f:(fun p ->
             List.mem b.Canary_overview_flow.bx_held p.pn_name ~equal:String.equal))
        b.Canary_overview_flow.bx_name)

let anchor (name : string) : string = "pin-" ^ name

(** One row per file: its subject, its path, its pins, the boxes they hold. *)
let table (files : file list) : string =
  let row f =
    Printf.sprintf "<tr><th>%s</th><td><code>%s</code></td><td>%d</td><td>%s</td></tr>"
      (esc f.pf_subject) (esc f.pf_path) (List.length f.pf_pins)
      (esc (String.concat ~sep:", " (boxes_held f.pf_pins)))
  in
  Canary_overview_exhibits.table ~cls:"pintab" "tab-pins"
  ^ {|<tr><th>about</th><th>file</th><th>pins</th><th>boxes of Figure 1 they hold</th></tr>|}
  ^ String.concat ~sep:"\n" (List.map files ~f:row)
  ^ "</table>"

(** Each file's pins: the name, the claim, and the boxes it holds. *)
let lists (files : file list) : string =
  let pin p =
    let held = boxes_held [ p ] in
    Printf.sprintf {|<dt id="%s"><code>%s</code></dt><dd>%s%s</dd>|} (esc (anchor p.pn_name))
      (esc p.pn_name) (esc p.pn_holds)
      (if List.is_empty held then ""
       else
         Printf.sprintf {| <span class="pinbox">Figure 1: %s</span>|}
           (esc (String.concat ~sep:", " held)))
  in
  String.concat ~sep:"\n"
    (List.map files ~f:(fun f ->
         Printf.sprintf
           {|<details class="pins"><summary>%s: <code>%s</code>, %d pins</summary><dl>%s</dl></details>|}
           (esc f.pf_subject)
           (esc (Stdlib.Filename.basename f.pf_path))
           (List.length f.pf_pins)
           (String.concat (List.map f.pf_pins ~f:pin))))

(** §0.4 as text, for [canary overview --flow]. *)
let text (files : file list) : string =
  "\nThe pins\n"
  ^ String.concat
      (List.map files ~f:(fun f ->
           Printf.sprintf "  %s: %s, %d pins\n%s" f.pf_subject f.pf_path (List.length f.pf_pins)
             (String.concat
                (List.map f.pf_pins ~f:(fun p -> Printf.sprintf "    %s: %s\n" p.pn_name p.pn_holds)))))

(** §0.4 of the overview page: every test [canary project-test] runs,
    under the file it is written in, with the claim it holds and the boxes
    of Figure 1 it holds. The tests come in as data, from
    [Canary_tests.test_files]: the test modules render this page, so the
    page cannot name them. *)

open Base

let esc = Canary_overview_assets.esc

type test = { ts_name : string; ts_holds : string }

(** A test file: what its tests are about, its path, its tests in run order. *)
type file = { tf_subject : string; tf_path : string; tf_tests : test list }

(** The boxes of Figure 1 the tests hold, in the figure's order. *)
let boxes_held (tests : test list) : string list =
  List.filter_map Canary_overview_flow.boxes ~f:(fun b ->
      Option.some_if
        (List.exists tests ~f:(fun t ->
             List.mem b.Canary_overview_flow.bx_held t.ts_name ~equal:String.equal))
        b.Canary_overview_flow.bx_name)

let anchor (name : string) : string = "test-" ^ name

(** One row per file: its subject, its path, its tests, the boxes they hold. *)
let table (files : file list) : string =
  let row f =
    Printf.sprintf "<tr><th>%s</th><td><code>%s</code></td><td>%d</td><td>%s</td></tr>"
      (esc f.tf_subject) (esc f.tf_path) (List.length f.tf_tests)
      (esc (String.concat ~sep:", " (boxes_held f.tf_tests)))
  in
  Canary_overview_exhibits.table ~cls:"testtab" "tab-tests"
  ^ {|<tr><th>about</th><th>file</th><th>tests</th><th>boxes of Figure 1 they hold</th></tr>|}
  ^ String.concat ~sep:"\n" (List.map files ~f:row)
  ^ "</table>"

(** Each file's tests: the name, the claim, and the boxes it holds. *)
let lists (files : file list) : string =
  let test t =
    let held = boxes_held [ t ] in
    Printf.sprintf {|<dt id="%s"><code>%s</code></dt><dd>%s%s</dd>|} (esc (anchor t.ts_name))
      (esc t.ts_name) (esc t.ts_holds)
      (if List.is_empty held then ""
       else
         Printf.sprintf {| <span class="testbox">Figure 1: %s</span>|}
           (esc (String.concat ~sep:", " held)))
  in
  String.concat ~sep:"\n"
    (List.map files ~f:(fun f ->
         Printf.sprintf
           {|<details class="tests"><summary>%s: <code>%s</code>, %d tests</summary><dl>%s</dl></details>|}
           (esc f.tf_subject)
           (esc (Stdlib.Filename.basename f.tf_path))
           (List.length f.tf_tests)
           (String.concat (List.map f.tf_tests ~f:test))))

(** A file's line in §0.4's text: its subject, its path, how many [noun]s
    it holds. *)
let text_file ?(noun = "test") (f : file) : string =
  let n = List.length f.tf_tests in
  Printf.sprintf "  %s: %s, %d %s%s\n" f.tf_subject f.tf_path n noun (if n = 1 then "" else "s")

(** A test's line in §0.4's text, after its [mark] when it has one. *)
let text_test ?(mark = "") (t : test) : string =
  Printf.sprintf "    %s%s: %s\n" mark t.ts_name t.ts_holds

(** §0.4 as text, for [canary overview --flow]. The harness lists its
    checks in the same lines, each marked with its verdict. *)
let text (files : file list) : string =
  "\nThe tests\n"
  ^ String.concat
      (List.map files ~f:(fun f ->
           text_file f ^ String.concat (List.map f.tf_tests ~f:(fun t -> text_test t))))

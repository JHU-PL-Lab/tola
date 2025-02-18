open Langs.Lang_mantle

[@@@ocamlformat "disable"]
(* https://ocaml.org/p/ocamlformat/0.26.2/doc/manpage_ocamlformat.html *)
let script_content = "
#!/bin/sh
printenv
echo $MY_VAR
"
let script_template : _ format = "
#!/bin/sh
echo $%s"
[@@@ocamlformat "enable"]

let script_for_get name = Printf.sprintf script_template name
let correct_get = ExpList [ Set ("a", "foo"); Get "a" ]
let incorrect_get = Get "a"
let set_inherit_get = ExpList [ Set ("a", "foo"); RunExp (Inherit, Get "a") ]

let export_inherit_e_get =
  ExpList [ Export ("a", "foo"); RunExp (Inherit, Get "a") ]

let e1 =
  ExpList
    [
      Set ("X", "42");
      Set ("PATH", "/usr/bin");
      Get "x";
      Set ("MY_VAR", "hello");
      Export ("MY_VAR2", "hello");
      RunProcess (Inherit, script_for_get "X");
      RunProcess (Custom [ ("X", "100") ], script_for_get "X");
    ]

let all =
  [ correct_get; incorrect_get; set_inherit_get; export_inherit_e_get; e1 ]

(* let export_inherit_p_get =
    ExpList [ Export ("a", "foo"); RunProcess (Inherit, Get "a") ] *)

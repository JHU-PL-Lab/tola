open Langs.Short

let () =
  Fmt.pr "\n%s" (Short4_id.show Examples.x);
  Short_id.dump_domain ();
  Short_lang.dump_domain ()

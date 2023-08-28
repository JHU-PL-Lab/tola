open Langs.Text_plain
open Interp

(* for naive text *)

let dump e = Fmt.pr "%s@." (Text_plain_interp.interp e)

let () =
  dump (Lit "Hi");
  dump (Con (Lit "Hello", Lit ", World!"))

(* for text with package *)

open Langs.Text_with_pkg

(* Pkgm.install "zfc" "Zermelo-Fraenkel set theory";;
   Pkgm.install "ac" "Axiom of Choices" *)

let dump_with_pkg e = Fmt.pr "%s@." (Text_with_pkgm_interp.interp e)
let e1 = Con (Con (Lit "I believe ", Pid "zfc"), Con (Lit " and ", Pid "ac"))
let e2 = Con (Con (Lit "I believe ", Pid "zfc"), Con (Lit " but not ", Pid "ac"))

let () =
  dump_with_pkg e1;
  dump_with_pkg e2

(* parser *)

let parse_then_dump s =
  Parser.Text_with_pkg.parse s |> Fmt.pr "%a@." Parser.Text_with_pkg.Pp.exp

let () =
  parse_then_dump "hi";
  parse_then_dump "hi@ac@"

let parse_then_interp s = Parser.Text_with_pkg.parse s |> dump_with_pkg

let () =
  parse_then_interp "I believe @zfc@ and @ac@.";
  parse_then_interp "I believe @zfc@ but not @ac@."

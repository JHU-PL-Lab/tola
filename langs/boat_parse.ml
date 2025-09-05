open Base
open Lang_boat

let of_string_no_eol_opt (line : string) =
  let linebuf = Lexing.from_string (line ^ "\n") in
  try Some (Boat_parser.main Boat_lexer.token linebuf) with
  | Boat_lexer.Error msg ->
      Stdio.eprintf "%s%!" msg;
      None
  | Boat_parser.Error ->
      Stdio.eprintf "At offset %d: syntax error.\n%!"
        (Lexing.lexeme_start linebuf);
      None

let of_string_opt (line : string) =
  let linebuf = Lexing.from_string line in
  try Some (Boat_parser.main Boat_lexer.token linebuf) with
  | Boat_lexer.Error msg ->
      Stdio.eprintf "%s%!" msg;
      None
  | Boat_parser.Error ->
      Stdio.eprintf "At offset %d: syntax error.\n%!"
        (Lexing.lexeme_start linebuf);
      None

let process (line : string) =
  let linebuf = Lexing.from_string line in
  try
    Stdio.printf "%s\n%!" (show_exp (Boat_parser.main Boat_lexer.token linebuf))
  with
  | Boat_lexer.Error msg -> Stdio.eprintf "%s%!" msg
  | Boat_parser.Error ->
      Stdio.eprintf "At offset %d: syntax error.\n%!"
        (Lexing.lexeme_start linebuf)

let process (optional_line : string option) =
  match optional_line with None -> () | Some line -> process line

let rec repeat channel =
  let optional_line, continue = Boat_lexer.line channel in
  process optional_line;
  if continue then repeat channel

(* let () = repeat (Lexing.from_channel stdin) *)

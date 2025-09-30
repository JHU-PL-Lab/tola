open Base

module Plain = struct
  type exp = Lit of string | Con of exp * exp
end

open Packaging

module Make (P : Package.PNAME) = struct
  type exp = Lit of string | Con of exp * exp | Pid of P.t
end

module With_string_pid = Make (Package.String_pname)

module Parse = struct
  open With_string_pid

  type state = Accu_lit | Accu_pid | Escaped_lit
  type event = Char of char | At | Escape

  let event_of_char ch =
    match ch with '@' -> At | '\\' -> Escape | _ -> Char ch

  let cons e1 buf f =
    if Sequence.length buf = 0 then e1
    else
      let s = buf |> Sequence.to_list |> String.of_char_list in
      let e2 = f s in
      if Poly.(e1 = Lit "") then e2 else Con (e1, e2)

  let parse (raw : string) : exp =
    let prev, buf, acc =
      String.fold
        ~f:(fun (prev, buf, acc) ch ->
          match (prev, event_of_char ch) with
          | Accu_lit, At ->
              (Accu_pid, Sequence.empty, cons acc buf (fun x -> Lit x))
          | Accu_lit, Char ch ->
              (Accu_lit, Sequence.(append buf (return ch)), acc)
          | Accu_lit, Escape ->
              (Escaped_lit, Sequence.(append buf (return ch)), acc)
          | Accu_pid, At ->
              (Accu_lit, Sequence.empty, cons acc buf (fun x -> Pid x))
          | Accu_pid, Char ch ->
              (Accu_pid, Sequence.(append buf (return ch)), acc)
          | Accu_pid, Escape -> failwith "pid doesn't allow escape"
          | Escaped_lit, _ -> (Accu_lit, Sequence.(append buf (return ch)), acc))
        ~init:(Accu_lit, Sequence.empty, Lit "")
        raw
    in
    match prev with
    | Accu_lit -> cons acc buf (fun x -> Lit x)
    | _ -> failwith "wrong ending state"

  module Pp = struct
    let rec exp oc e =
      match e with
      | Lit s -> Fmt.pf oc "Lit %s" s
      | Con (e1, e2) -> Fmt.pf oc "(%a %a)" exp e1 exp e2
      | Pid pid -> Fmt.pf oc "[%s]" pid
  end
end

open Base
open Packaging
open Langs.Lang_text.Plain

let rec interp e =
  match e with Lit s -> s | Con (e1, e2) -> interp e1 ^ interp e2

open Langs.Lang_text.With_string_pid

module Make_interp (PM : Manager.S with type P.payload = string) = struct
  let lookup_pkg_payload pm pname =
    pname |> PM.lookup_local pm |> PM.P.payload_of_pkg

  let interp pm e =
    let rec interp e =
      match e with
      | Lit s -> s
      | Pid pid ->
          lookup_pkg_payload pm pid |> Langs.Lang_text.Parse.parse |> interp
      | Con (e1, e2) -> interp e1 ^ interp e2
    in
    interp e
end

module Make_interp_via_pname (PM : Manager.S with type P.payload = exp) = struct
  let lookup_pkg_payload pm pid_s =
    pid_s |> PM.lookup_local pm |> PM.P.payload_of_pkg

  let interp pm e =
    let rec interp e =
      match e with
      | Lit s -> s
      | Pid pid_s ->
          lookup_pkg_payload pm pid_s
          (*|> Langs.Lang_text.Parse.parse *) |> interp
      | Con (e1, e2) -> interp e1 ^ interp e2
    in
    interp e

  let interp_s pm s = s |> Langs.Lang_text.Parse.parse |> interp pm
end

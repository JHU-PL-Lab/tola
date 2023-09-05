module Plain = struct
  type exp = Lit of string | Con of exp * exp
end

open Packaging

module Make (P : Package.PACKAGE) = struct
  type pid = P.pid
  type pkg = P.pkg
  type exp = Lit of string | Con of exp * exp | Pid of pid
end

module With_string_pkg = Make (Package.String_pkg)

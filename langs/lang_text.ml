module Plain = struct
  type exp = Lit of string | Con of exp * exp
end

open Packaging

module Make (P : Package.PACKAGE) = struct
  type exp = Lit of string | Con of exp * exp | Pid of P.pid
end

module With_string_pid = Make (Package.Naive_pkg)

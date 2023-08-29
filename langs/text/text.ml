module Plain = struct
  type exp = Lit of string | Con of exp * exp
end

module Make (P : Package.Naive.PACKAGE) = struct
  type pid = P.pid
  type pkg = P.pkg
  type exp = Lit of string | Con of exp * exp | Pid of pid
end

module With_string_pkg = Make (struct
  type pid = Package.Naive.String_pkg.pid
  type pkg = Package.Naive.String_pkg.pkg
end)

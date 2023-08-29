module Plain = struct
  type exp = Lit of string | Con of exp * exp
end

module Make (P : Package.PACKAGE) = struct
  type pid = P.pid
  type pkg = P.pkg
  type exp = Lit of string | Con of exp * exp | Pid of pid
end

module With_string_pkg = Make (Package.String_pkg)

module Pkgm_persisted =
  Package_manager.Naive_pkgm.Make
    (Package.String_pkg)
    (Package_manager.Shared.Pkg_table)

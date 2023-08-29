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

module Text_pkgm_config : Naive.NAIVE_CONFIG = struct
  let home = Sys.getenv "HOME"
  let pkgm_id = "text"
  let pkgm_root = home ^ "/.pkgm"
end

module Pkgm_persisted =
  Naive_pkgm.Make (Package.String_pkg) (Shared.Pkg_table) (Text_pkgm_config)

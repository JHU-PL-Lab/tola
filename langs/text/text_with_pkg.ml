open Naive_pkgm

type pid = Pkg.pid
type pkg = Pkg.pkg
type exp = Lit of string | Con of exp * exp | Pid of pid

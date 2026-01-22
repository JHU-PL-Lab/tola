type os = OpamStd.Sys.os

type distro =
  | Ubuntu
  | Debian
  | Fedora
  | Arch
  | Alpine
  | MacOS_Brew
  | MacOS_Macports
  | Windows_MSYS
  | Windows_Mingw
  | Windows_Msvc
  | Unknown_distro of string

type arch = X86_64 | Aarch64 | Armv7 | Riscv64 | Other_arch of string
type t = { os : os; distro : distro; arch : arch }
type lang = OCaml | Cpp | C | Python | Java | Text
type build_systgem = Dune | CMake | Make | Shell | Custom of string

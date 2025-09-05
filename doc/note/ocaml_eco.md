[dune/the-ocaml-ecosystem](https://dune.readthedocs.io/en/stable/explanation/ocaml-ecosystem.html)

**ocaml compiler**: compiling and linking

**findlib**

- Defines the concept of library, on the top of the notion of module.
- Definitions of libraries and other metadata are stored in `META` files
- Dhips `ocamlfind`

**opam**

- A package manager
- The notion of version is specific to opam
- `opam-repository` is a package database

**dune**

- A build system, used to orchestrate the compilation of source files into executables and libraries.
- Knows build commands for source files
- Outputs metadata like `META`
- Generate opam files, which is used by `@install` and `@runtest`
- OCaml ecosystem does not have a centralized toolchain
  - Units such as modules, libraries, and packages operate at different levels
  - and the relation between these can be confusing to users.
- Dune's choice by default
  - Expose a single top-level module named after the library (called a wrapped library)
  - A library can only be installed in the package on the same name
    - package names of `dune-project` and `opam` are the same of names found in `dune` (library name)

## META man page

https://www.mankier.com/5/META
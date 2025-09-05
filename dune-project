(lang dune 3.10)

(name tola)

(using menhir 2.1)

(generate_opam_files true)

(maintainers "Shiwei Weng <weng@cs.jhu.edu>")

(package
 (name tola)
 (synopsis "thousands of languages")
 (description "I shall better \nwrite a better description.")
 (depends
  core
  core_unix
  fmt
  fix
  ppx_jane
  ppx_yojson_conv
  ; dev-dependency
  dune
  utop
  ocaml-lsp-server
  ocamlformat
  (alcotest :with-test)
  ppx_deriving
  cmdliner
  cmarkit
  ; The followings are obviously not related to this project but I have short time to clean them out yet.
  ocamlgraph
  color-brewery))

(license MIT)

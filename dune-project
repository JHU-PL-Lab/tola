(lang dune 3.10)

(generate_opam_files true)

(maintainers "Shiwei Weng <dota@jhu.edu>")

(package
 (name tola)
 (synopsis "thousands of languages")
 (description "I shall better \nwrite a better description.")
 (depends
  core
  fmt
  fix
  ppx_jane
  ; dev-dependency
  utop
  ocaml-lsp-server
  ocamlformat
  (alcotest :with-test)
  ; The followings are obviously not related to this project but I have short time to clean them out yet.
  ppx_deriving
  cmdliner
  feat
  ocamlgraph
  color-brewery))

(license MIT)

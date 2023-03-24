(lang dune 3.6)

(generate_opam_files true)

(authors "Shiwei Weng <shiwei@prover.me>")

(package
 (name tola)
 (synopsis "thousands of languages")
 (description "I shall better \nwrite a better description.")
 (depends core fix))

(package
 (name lattice)
 (synopsis "lattice library")
 (description "I shall better \nwrite a better description.")
 (depends
  (alcotest :with-test)))

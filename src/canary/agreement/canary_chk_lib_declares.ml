(** Checks that the BUILT lib presents what the project declared — the
    decl-comparison family (design §1.7, solo-artifact target).

    THE PATTERN, established here (user, 2026-09-02): one module per
    check family, holding its category, its falsifier-phrased statement,
    and its function. The function keeps the signature that suits it —
    there is deliberately no unified type yet — and the caller passes
    what it needs, including the declared facts to compare against and
    (where a check has one) the expected result.

    The tools that produce these artifacts are black boxes, so none of
    these trusts an exit code: each reads the artifact and compares it
    against the declaration. *)

open Base
module Cat = Canary_check_cat

(* ── every declared c_api function is exported ── *)

let symbol_exported_cat = Cat.Symbols `Exported
let symbol_exported_standing = Cat.Declared
let symbol_exported_says =
  "every function the project declares in c_api is exported by the \
   built lib"

let symbol_exported ~declared_functions ~resolve inputs =
  Canary_agreement_run.c1_decl_predict ~declared_functions ~resolve inputs

(* ── the elf soname is the declared one ── *)

let soname_matches_cat = Cat.Identity `Soname
let soname_matches_standing = Cat.Declared
let soname_matches_says =
  "the built lib's elf soname is the soname the project declared"

let soname_matches ~declared_soname ~resolve inputs =
  Canary_agreement_run.c4_decl_predict ~declared_soname ~resolve inputs

(* ── the declared version tags are exported ── *)

let version_tags_exported_cat = Cat.Identity `Version_node
let version_tags_exported_standing = Cat.Declared
let version_tags_exported_says =
  "every version tag the project declares appears among the built lib's \
   versioned exports"

let version_tags_exported ~declared_tags ~resolve inputs =
  Canary_agreement_run.c5_decl_predict ~declared_tags ~resolve inputs

(** The family, for the catalogue and the index. *)
let all : (Cat.cat * Cat.standing * string) list =
  [ (symbol_exported_cat, symbol_exported_standing, symbol_exported_says);
    (soname_matches_cat, soname_matches_standing, soname_matches_says);
    (version_tags_exported_cat, version_tags_exported_standing,
     version_tags_exported_says) ]

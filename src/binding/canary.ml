(*
  A compact model to enumerate test cases for a project like Z3 with:
  - src versions (old/dev)
  - API versions (old/dev), which may or may not change with src
  - lib_src: native library produced from src
  - lib_binding: language binding library that depends on either src (legacy) or lib_src (mainstream)
  - pkg_binding: a package manager artifact providing the binding
  - pkg_rev: a reverse-dependency package that depends on pkg_binding

  We intentionally only enumerate test cases by stage using cartesian products.
  How to execute tests for each case (build/install/deploy/user) can be decided later.
*)

(* ---------- Core version axis ---------- *)

(* 

canary testing matrix

src: src_z3
build : lib_z3_b, lib_binding_z3_b
install : lib_z3, lib_binding_z3
deploy : pkg_python_z3, pkg_ocaml_z3_src, pkg_ocaml_z3_lib
user : pkg_use_python_z3, pkg_use_ocaml_z3



artifacts:
ver_case = Old | Dev
old: 15.3

src (update) -> .... pkg_z3                                ... pkg_use_z3
                    (src_z3)+pkg_meta (e.g. .opam) **ocaml-z3.dev**
                    (lib_z3)+pkg_meta (e.g. .opam)



src
api...
lib_src
lib_binding
pkg_binding: ocaml-z3.15.3,  ocaml-z3.dev
  (package_meta (e.g. .opam) + src       src=15.3  ->  pkg=15.3 (X))
  package_meta (e.g. .opam)  src=dev   src=dev  ->   pkg=dev  (15.4)

c_api_lib_z3_give
c_api_spec_binding_assume
  e.g. ocaml ()
    one error build
    binding_mismatch

stages:=
build : libz3_c, lib_py (sort c api), lib_ml
install
deploy
user

*)

type ver_case = Old | Dev
type src_ver = SrcV of ver_case
type api_ver = ApiV of ver_case

(* API may change or stay the same across src versions. *)
type src_api_map = src_ver -> api_ver

(* ---------- Artifacts ---------- *)

type binding_lang = Python | OCaml
type pm = Pip | Opam

(* Native library built from the project source. *)
type lib_src = { src : src_ver; api : api_ver }

(* Binding may depend on src directly (legacy) or on an installed lib_src (mainstream). *)
type binding_dep = Dep_on_src of src_ver | Dep_on_lib_src of lib_src

(* A language binding library (glue + wrappers). *)
type lib_binding = { lang : binding_lang; dep : binding_dep; api : api_ver }

(* A package manager artifact providing a binding. *)
type pkg_binding = {
  pm : pm;
  lang : binding_lang;
  provides : lib_binding;
  pkg_ver : ver_case;
}

(* A reverse dependency package in the same package manager ecosystem. *)
type pkg_rev = {
  pm : pm;
  lang : binding_lang;
  uses : pkg_binding;
  pkg_ver : ver_case;
}

(* ---------- Stages (we only enumerate cases; execution is out of scope) ---------- *)

type stage = Build | Install | Deploy | User

(* A generic test case for any stage. Keep it simple: it's a bundle of artifacts. *)
type test_case = {
  stage : stage;
  lib_src_build : lib_src option;
  pkg_binding_install : pkg_binding option;
  pkg_rev_install : pkg_rev option;
  runtime_lib_src : lib_src option;
}

(* ---------- Small utilities ---------- *)

let all_versions : ver_case list = [ Old; Dev ]
let mk_src_ver v = SrcV v

let mk_lib_src (api_of_src : src_api_map) (v : ver_case) : lib_src =
  let src = mk_src_ver v in
  { src; api = api_of_src src }

let is_legacy (legacy : (binding_lang * ver_case) list) ~(lang : binding_lang)
    ~(v : ver_case) : bool =
  List.exists (fun (l, vv) -> l = lang && vv = v) legacy

let mk_lib_binding (api_of_src : src_api_map)
    ~(legacy_dep_on_src : (binding_lang * ver_case) list) ~(lang : binding_lang)
    ~(v : ver_case) : lib_binding =
  let src = mk_src_ver v in
  let api = api_of_src src in
  let dep =
    if is_legacy legacy_dep_on_src ~lang ~v then Dep_on_src src
    else Dep_on_lib_src (mk_lib_src api_of_src v)
  in
  { lang; dep; api }

let mk_pkg_binding (api_of_src : src_api_map)
    ~(legacy_dep_on_src : (binding_lang * ver_case) list) ~(pm : pm)
    ~(lang : binding_lang) ~(v : ver_case) : pkg_binding =
  {
    pm;
    lang;
    provides = mk_lib_binding api_of_src ~legacy_dep_on_src ~lang ~v;
    pkg_ver = v;
  }

let mk_pkg_rev (api_of_src : src_api_map)
    ~(legacy_dep_on_src : (binding_lang * ver_case) list) ~(pm : pm)
    ~(lang : binding_lang) ~(rev_depends_on_pkg_ver : ver_case)
    ~(rev_pkg_ver : ver_case) : pkg_rev =
  let uses =
    mk_pkg_binding api_of_src ~legacy_dep_on_src ~pm ~lang
      ~v:rev_depends_on_pkg_ver
  in
  { pm; lang; uses; pkg_ver = rev_pkg_ver }

(* ---------- Cartesian product helper ---------- *)

let cartesian_product (xs : 'a list) (ys : 'b list) : ('a * 'b) list =
  List.concat_map (fun x -> List.map (fun y -> (x, y)) ys) xs

(* ---------- Stage-specific enumerators ---------- *)

type cfg = {
  api_of_src : src_api_map;
      (* Mainstream is Dep_on_lib_src; these pairs are legacy Dep_on_src. *)
  legacy_dep_on_src : (binding_lang * ver_case) list;
      (* Which ecosystems/languages to enumerate packages for. *)
  pkg_matrix : (pm * binding_lang) list;
      (* Reverse-dep policy:
     - for each (pm, lang), whether there is a reverse dep package
     - if yes, which pkg_ver it depends on (Old or Dev)
     - and what version label the revdep itself is (Old/Dev) *)
  revdep_spec : pm * binding_lang -> (ver_case * ver_case) option;
}

(* Enumerate Build cases:
   - build lib_src for each src version
   - optionally also "build the package" conceptually by enumerating pkg_binding for each version
   (We keep the case structure uniform and lightweight.)
*)
let enumerate_build (cfg : cfg) : test_case list =
  let lib_srcs = List.map (mk_lib_src cfg.api_of_src) all_versions in
  let pkgs =
    cfg.pkg_matrix
    |> List.concat_map (fun (pm, lang) ->
        List.map
          (fun v ->
            mk_pkg_binding cfg.api_of_src
              ~legacy_dep_on_src:cfg.legacy_dep_on_src ~pm ~lang ~v)
          all_versions)
  in
  let lib_cases =
    List.map
      (fun ls ->
        {
          stage = Build;
          lib_src_build = Some ls;
          pkg_binding_install = None;
          pkg_rev_install = None;
          runtime_lib_src = None;
        })
      lib_srcs
  in
  let pkg_cases =
    List.map
      (fun p ->
        {
          stage = Build;
          lib_src_build = None;
          pkg_binding_install = Some p;
          pkg_rev_install = None;
          runtime_lib_src = None;
        })
      pkgs
  in
  lib_cases @ pkg_cases

(* Enumerate Install cases:
   - install pkg_binding for each pkg version
   - install pkg_rev (reverse dependency) if it exists for that ecosystem/language
*)
let enumerate_install (cfg : cfg) : test_case list =
  let pkgs =
    cfg.pkg_matrix
    |> List.concat_map (fun (pm, lang) ->
        List.map
          (fun v ->
            mk_pkg_binding cfg.api_of_src
              ~legacy_dep_on_src:cfg.legacy_dep_on_src ~pm ~lang ~v)
          all_versions)
  in
  let revs =
    cfg.pkg_matrix
    |> List.filter_map (fun (pm, lang) ->
        match cfg.revdep_spec (pm, lang) with
        | None -> None
        | Some (depends_on_pkg_ver, rev_pkg_ver) ->
            Some
              (mk_pkg_rev cfg.api_of_src
                 ~legacy_dep_on_src:cfg.legacy_dep_on_src ~pm ~lang
                 ~rev_depends_on_pkg_ver:depends_on_pkg_ver ~rev_pkg_ver))
  in
  let pkg_cases =
    List.map
      (fun p ->
        {
          stage = Install;
          lib_src_build = None;
          pkg_binding_install = Some p;
          pkg_rev_install = None;
          runtime_lib_src = None;
        })
      pkgs
  in
  let rev_cases =
    List.map
      (fun r ->
        {
          stage = Install;
          lib_src_build = None;
          pkg_binding_install = None;
          pkg_rev_install = Some r;
          runtime_lib_src = None;
        })
      revs
  in
  pkg_cases @ rev_cases

(* Enumerate Deploy cases:
   - take each pkg_binding (old/dev) and pair it with each runtime lib_src (old/dev)
   - similarly for each pkg_rev
   This models "after deployment, what native lib is actually present/loaded".
*)
let enumerate_deploy (cfg : cfg) : test_case list =
  let runtime_libs = List.map (mk_lib_src cfg.api_of_src) all_versions in

  let pkgs =
    cfg.pkg_matrix
    |> List.concat_map (fun (pm, lang) ->
        List.map
          (fun v ->
            mk_pkg_binding cfg.api_of_src
              ~legacy_dep_on_src:cfg.legacy_dep_on_src ~pm ~lang ~v)
          all_versions)
  in

  let revs =
    cfg.pkg_matrix
    |> List.filter_map (fun (pm, lang) ->
        match cfg.revdep_spec (pm, lang) with
        | None -> None
        | Some (depends_on_pkg_ver, rev_pkg_ver) ->
            Some
              (mk_pkg_rev cfg.api_of_src
                 ~legacy_dep_on_src:cfg.legacy_dep_on_src ~pm ~lang
                 ~rev_depends_on_pkg_ver:depends_on_pkg_ver ~rev_pkg_ver))
  in

  let pkg_pairs = cartesian_product pkgs runtime_libs in
  let rev_pairs = cartesian_product revs runtime_libs in

  let pkg_cases =
    List.map
      (fun (p, rt) ->
        {
          stage = Deploy;
          lib_src_build = None;
          pkg_binding_install = Some p;
          pkg_rev_install = None;
          runtime_lib_src = Some rt;
        })
      pkg_pairs
  in

  let rev_cases =
    List.map
      (fun (r, rt) ->
        {
          stage = Deploy;
          lib_src_build = None;
          pkg_binding_install = None;
          pkg_rev_install = Some r;
          runtime_lib_src = Some rt;
        })
      rev_pairs
  in
  pkg_cases @ rev_cases

(* Enumerate User cases:
   Same cartesian pairing as Deploy, but tagged as User stage.
   Actual smoke/conformance test selection is intentionally deferred.
*)
let enumerate_user (cfg : cfg) : test_case list =
  let runtime_libs = List.map (mk_lib_src cfg.api_of_src) all_versions in

  let pkgs =
    cfg.pkg_matrix
    |> List.concat_map (fun (pm, lang) ->
        List.map
          (fun v ->
            mk_pkg_binding cfg.api_of_src
              ~legacy_dep_on_src:cfg.legacy_dep_on_src ~pm ~lang ~v)
          all_versions)
  in

  let revs =
    cfg.pkg_matrix
    |> List.filter_map (fun (pm, lang) ->
        match cfg.revdep_spec (pm, lang) with
        | None -> None
        | Some (depends_on_pkg_ver, rev_pkg_ver) ->
            Some
              (mk_pkg_rev cfg.api_of_src
                 ~legacy_dep_on_src:cfg.legacy_dep_on_src ~pm ~lang
                 ~rev_depends_on_pkg_ver:depends_on_pkg_ver ~rev_pkg_ver))
  in

  let pkg_pairs = cartesian_product pkgs runtime_libs in
  let rev_pairs = cartesian_product revs runtime_libs in

  let pkg_cases =
    List.map
      (fun (p, rt) ->
        {
          stage = User;
          lib_src_build = None;
          pkg_binding_install = Some p;
          pkg_rev_install = None;
          runtime_lib_src = Some rt;
        })
      pkg_pairs
  in

  let rev_cases =
    List.map
      (fun (r, rt) ->
        {
          stage = User;
          lib_src_build = None;
          pkg_binding_install = None;
          pkg_rev_install = Some r;
          runtime_lib_src = Some rt;
        })
      rev_pairs
  in
  pkg_cases @ rev_cases

(* ---------- Unified entrypoint ---------- *)

type plan = {
  build : test_case list;
  install : test_case list;
  deploy : test_case list;
  user : test_case list;
}

let enumerate_plan (cfg : cfg) : plan =
  {
    build = enumerate_build cfg;
    install = enumerate_install cfg;
    deploy = enumerate_deploy cfg;
    user = enumerate_user cfg;
  }

(* ---------- Example configuration (Python + OCaml) ---------- *)

let default_cfg : cfg =
  {
    api_of_src =
      (fun (SrcV v) -> match v with Old -> ApiV Old | Dev -> ApiV Dev);
    legacy_dep_on_src =
      [] (* e.g. [(OCaml, Old)] if OCaml old is legacy Dep_on_src *);
    pkg_matrix = [ (Pip, Python); (Opam, OCaml) ];
    revdep_spec =
      (fun (_pm, _lang) -> Some (Dev, Dev))
      (* (depends_on_pkg_ver, rev_pkg_ver) *);
  }

let default_plan : plan = enumerate_plan default_cfg

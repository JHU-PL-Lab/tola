(* ── The wrapper-package opam template (2026-08-17, active plan 2) ──

   ONE skeleton, per-project build bodies: the wrapper packages in
   canary/templates/opam-local-repo/ differ only in the build body
   (cmake+ninja / cmake / configure+make) + metadata; the skeleton is
   common. The rendered files stay COMMITTED (the repo remains
   standalone-usable); the pin [tool.opam_template_render] asserts the
   renderer reproduces zarith-no-conf's committed file byte-equal —
   the M2 byte-equal discipline. z3.dev's working .tpl flow migrates
   to this renderer later (the playbook's refactor plan,
   doc/canary/design/action_playbook.md). *)

type wrapper_decl = {
  pkg : string;               (* "zarith-no-conf" *)
  src_var : string;           (* CANARY_ZARITH_SRC — the url src var *)
  maintainer : string;
  authors : string;
  homepage : string;
  bug_reports : string;
  license : string;
  dev_repo : string;
  build_body : string;        (* the build: list body, e.g. [ "sh" "-ec" "..." ] *)
  install_body : string;      (* the install: list body *)
  remove_body : string;       (* the remove: list body, e.g. "ocamlfind" "remove" "zarith" *)
  depends : string list;      (* already opam-formatted entries *)
  conflicts : string list;    (* BARE package names — the renderer quotes
                                 them; the pack primitive drops them from
                                 the store before installing *)
  synopsis : string;
  description : string;       (* the raw """...""" body, no delimiters *)
}

let render (d : wrapper_decl) : string =
  String.concat "\n"
    [ "opam-version: \"2.0\"";
      Printf.sprintf "maintainer: \"%s\"" d.maintainer;
      Printf.sprintf "authors: \"%s\"" d.authors;
      Printf.sprintf "homepage: \"%s\"" d.homepage;
      Printf.sprintf "bug-reports: \"%s\"" d.bug_reports;
      Printf.sprintf "license: \"%s\"" d.license;
      Printf.sprintf "dev-repo: \"%s\"" d.dev_repo;
      "build: [";
      "  " ^ d.build_body;
      "]";
      "install: [";
      "  " ^ d.install_body;
      "]";
      Printf.sprintf "remove: [%s]" d.remove_body;
      "depends: [";
      String.concat "\n"
        (List.map (fun e -> "  " ^ e) d.depends);
      "]";
      "conflicts: [";
      String.concat "\n"
        (List.map (fun c -> Printf.sprintf "  \"%s\"" c) d.conflicts);
      "]";
      Printf.sprintf "synopsis: \"%s\"" d.synopsis;
      "description: \"\"\"";
      d.description;
      "\"\"\"";
      "url {";
      Printf.sprintf "  src: \"%%{%s}%%\"" d.src_var;
      "}" ]
  ^ "\n"

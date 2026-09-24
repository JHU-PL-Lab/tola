(window.CANARY_RUNS = window.CANARY_RUNS || []).push(
{
  "machine": "wsl_ubuntu",
  "generated": "2026-09-23 20:44",
  "views": [
    {
      "id": "be0605-ocaml",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:43:56.105", "2026-09-23 20:44:02.274" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "ran",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "ran",
        "install_lang": "ran",
        "install_surf": "ran",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "realize_sys": "violated",
        "build_lib": "violated",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "B:s",
        "mod_lang": "opam sqlite3.5.1.0"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (1 modules)", "from": "recorded" },
        "stub_lang": { "label": "libsqlite3_stubs.a", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "bridge": { "label": "conf-sqlite3", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "surf_lang": { "label": "sqlite3.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "staged_sys", "cap", "src_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "be0605-python",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:43:56.105", "2026-09-23 20:44:02.297" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "undecided",
        "soname_matches_requirement": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "realize_sys": "violated",
        "build_lib": "violated",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "B:s",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "fetch_binding_python": "a dummy step: it performs nothing",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (210 names)", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "pm_lang": { "label": "pip", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "stub_lang": { "label": "_sqlite3*.so", "from": "declared" },
        "surf_lang": { "label": "sqlite3/__init__.py", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "staged_sys", "cap", "bridge",
        "pm_lang", "src_lang", "stub_lang", "surf_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "df925e-ocaml",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:44:04.260", "2026-09-23 20:44:10.635" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "ran",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "ran",
        "install_lang": "ran",
        "install_surf": "ran",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "realize_sys": "violated",
        "build_lib": "violated",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "B:s",
        "mod_lang": "opam sqlite3.5.4.1"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (1 modules)", "from": "recorded" },
        "stub_lang": { "label": "libsqlite3_stubs.a", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "bridge": { "label": "conf-sqlite3", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "surf_lang": { "label": "sqlite3.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "staged_sys", "cap", "src_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "df925e-python",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:44:04.260", "2026-09-23 20:44:10.659" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "undecided",
        "soname_matches_requirement": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "realize_sys": "violated",
        "build_lib": "violated",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "B:s",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "fetch_binding_python": "a dummy step: it performs nothing",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (210 names)", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "pm_lang": { "label": "pip", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "stub_lang": { "label": "_sqlite3*.so", "from": "declared" },
        "surf_lang": { "label": "sqlite3/__init__.py", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "staged_sys", "cap", "bridge",
        "pm_lang", "src_lang", "stub_lang", "surf_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "bf7656-ocaml",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:44:03.238", "2026-09-23 20:44:04.159" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "warm",
        "depext": "not_ours",
        "depends": "warm",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds",
        "staged_interface_preserved": "holds"
      },
      "badges": {
        "realize_sys": "violated",
        "build_lib": "violated",
        "stage": "holds",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "I:s",
        "mod_lang": "opam sqlite3.5.1.0"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "probe_lib_staged": "observes the staged copy, which has no observation edge",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (1 modules)", "from": "recorded" },
        "stub_lang": { "label": "libsqlite3_stubs.a", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "bridge": { "label": "conf-sqlite3", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "surf_lang": { "label": "sqlite3.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "cap", "src_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "bf7656-python",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:44:03.238", "2026-09-23 20:44:04.184" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "warm",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "undecided",
        "soname_matches_requirement": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "api_names_present": "holds",
        "staged_interface_preserved": "holds"
      },
      "badges": {
        "realize_sys": "violated",
        "build_lib": "violated",
        "stage": "holds",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "I:s",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "fetch_binding_python": "a dummy step: it performs nothing",
        "probe_lib_staged": "observes the staged copy, which has no observation edge",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (210 names)", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "pm_lang": { "label": "pip", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "stub_lang": { "label": "_sqlite3*.so", "from": "declared" },
        "surf_lang": { "label": "sqlite3/__init__.py", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "cap", "bridge", "pm_lang",
        "src_lang", "stub_lang", "surf_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "e35b2b-ocaml",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:44:11.626", "2026-09-23 20:44:12.618" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "warm",
        "depext": "not_ours",
        "depends": "warm",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds",
        "staged_interface_preserved": "holds"
      },
      "badges": {
        "realize_sys": "violated",
        "build_lib": "violated",
        "stage": "holds",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "I:s",
        "mod_lang": "opam sqlite3.5.4.1"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "probe_lib_staged": "observes the staged copy, which has no observation edge",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (1 modules)", "from": "recorded" },
        "stub_lang": { "label": "libsqlite3_stubs.a", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "bridge": { "label": "conf-sqlite3", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "surf_lang": { "label": "sqlite3.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "cap", "src_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "e35b2b-python",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:44:11.626", "2026-09-23 20:44:12.642" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "warm",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "undecided",
        "soname_matches_requirement": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "api_names_present": "holds",
        "staged_interface_preserved": "holds"
      },
      "badges": {
        "realize_sys": "violated",
        "build_lib": "violated",
        "stage": "holds",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "I:s",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "fetch_binding_python": "a dummy step: it performs nothing",
        "probe_lib_staged": "observes the staged copy, which has no observation edge",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (210 names)", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "pm_lang": { "label": "pip", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "stub_lang": { "label": "_sqlite3*.so", "from": "declared" },
        "surf_lang": { "label": "sqlite3/__init__.py", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "cap", "bridge", "pm_lang",
        "src_lang", "stub_lang", "surf_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "08b7dd-ocaml",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:43:38.094", "2026-09-23 20:43:44.517" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "ran",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "ran",
        "install_lang": "ran",
        "install_surf": "ran",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "realize_sys": "partial",
        "build_lib": "partial",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "B:d",
        "mod_lang": "opam sqlite3.5.1.0"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (1 modules)", "from": "recorded" },
        "stub_lang": { "label": "libsqlite3_stubs.a", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "bridge": { "label": "conf-sqlite3", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "surf_lang": { "label": "sqlite3.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "staged_sys", "cap", "src_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "08b7dd-python",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:43:38.094", "2026-09-23 20:43:44.543" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "undecided",
        "soname_matches_requirement": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "realize_sys": "partial",
        "build_lib": "partial",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "B:d",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "fetch_binding_python": "a dummy step: it performs nothing",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (210 names)", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "pm_lang": { "label": "pip", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "stub_lang": { "label": "_sqlite3*.so", "from": "declared" },
        "surf_lang": { "label": "sqlite3/__init__.py", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "staged_sys", "cap", "bridge",
        "pm_lang", "src_lang", "stub_lang", "surf_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "b8e9cb-ocaml",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:43:46.860", "2026-09-23 20:43:53.314" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "ran",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "ran",
        "install_lang": "ran",
        "install_surf": "ran",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "realize_sys": "partial",
        "build_lib": "partial",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "B:d",
        "mod_lang": "opam sqlite3.5.4.1"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (1 modules)", "from": "recorded" },
        "stub_lang": { "label": "libsqlite3_stubs.a", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "bridge": { "label": "conf-sqlite3", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "surf_lang": { "label": "sqlite3.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "staged_sys", "cap", "src_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "b8e9cb-python",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:43:46.860", "2026-09-23 20:43:53.340" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "undecided",
        "soname_matches_requirement": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "realize_sys": "partial",
        "build_lib": "partial",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "B:d",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "fetch_binding_python": "a dummy step: it performs nothing",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (210 names)", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "pm_lang": { "label": "pip", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "stub_lang": { "label": "_sqlite3*.so", "from": "declared" },
        "surf_lang": { "label": "sqlite3/__init__.py", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "staged_sys", "cap", "bridge",
        "pm_lang", "src_lang", "stub_lang", "surf_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "740478-ocaml",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:43:44.622", "2026-09-23 20:43:45.626" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "warm",
        "depext": "not_ours",
        "depends": "warm",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds",
        "staged_interface_preserved": "holds"
      },
      "badges": {
        "realize_sys": "partial",
        "build_lib": "partial",
        "stage": "holds",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "I:d",
        "mod_lang": "opam sqlite3.5.1.0"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "probe_lib_staged": "observes the staged copy, which has no observation edge",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (1 modules)", "from": "recorded" },
        "stub_lang": { "label": "libsqlite3_stubs.a", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "bridge": { "label": "conf-sqlite3", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "surf_lang": { "label": "sqlite3.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "cap", "src_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "740478-python",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:43:44.622", "2026-09-23 20:43:45.653" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "warm",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "undecided",
        "soname_matches_requirement": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "api_names_present": "holds",
        "staged_interface_preserved": "holds"
      },
      "badges": {
        "realize_sys": "partial",
        "build_lib": "partial",
        "stage": "holds",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "I:d",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "fetch_binding_python": "a dummy step: it performs nothing",
        "probe_lib_staged": "observes the staged copy, which has no observation edge",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (210 names)", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "pm_lang": { "label": "pip", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "stub_lang": { "label": "_sqlite3*.so", "from": "declared" },
        "surf_lang": { "label": "sqlite3/__init__.py", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "cap", "bridge", "pm_lang",
        "src_lang", "stub_lang", "surf_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "170e8d-ocaml",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:43:53.420", "2026-09-23 20:43:54.384" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "warm",
        "depext": "not_ours",
        "depends": "warm",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds",
        "staged_interface_preserved": "holds"
      },
      "badges": {
        "realize_sys": "partial",
        "build_lib": "partial",
        "stage": "holds",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "I:d",
        "mod_lang": "opam sqlite3.5.4.1"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "probe_lib_staged": "observes the staged copy, which has no observation edge",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (1 modules)", "from": "recorded" },
        "stub_lang": { "label": "libsqlite3_stubs.a", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "bridge": { "label": "conf-sqlite3", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "surf_lang": { "label": "sqlite3.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "cap", "src_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "170e8d-python",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:43:53.420", "2026-09-23 20:43:54.410" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "warm",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "soname_matches_declaration": "holds",
        "declared_versions_exported": "undecided",
        "required_symbols_exported": "undecided",
        "soname_matches_requirement": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "api_names_present": "holds",
        "staged_interface_preserved": "holds"
      },
      "badges": {
        "realize_sys": "partial",
        "build_lib": "partial",
        "stage": "holds",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "I:d",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "fetch_binding_python": "a dummy step: it performs nothing",
        "probe_lib_staged": "observes the staged copy, which has no observation edge",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (210 names)", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "pm_lang": { "label": "pip", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "stub_lang": { "label": "_sqlite3*.so", "from": "declared" },
        "surf_lang": { "label": "sqlite3/__init__.py", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "hdr_sys", "cap", "bridge", "pm_lang",
        "src_lang", "stub_lang", "surf_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "c2ff32-ocaml",
      "project": "sqlite",
      "scenario": "source-fetched_lib-fetched_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:44:02.374", "2026-09-23 20:44:03.142" ],
      "edges": {
        "resolve_sys": "warm",
        "realize_sys": "warm",
        "realize_hdr": "warm",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "warm",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "apt sqlite3.3.45.1",
        "mod_lang": "opam sqlite3.5.1.0"
      },
      "unplaced": {},
      "names": {
        "mod_lang": { "label": "sqlite3 (1 modules)", "from": "recorded" },
        "stub_lang": { "label": "libsqlite3_stubs.a", "from": "recorded" },
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "bridge": { "label": "conf-sqlite3", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "surf_lang": { "label": "sqlite3.mli", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "src_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "c2ff32-python",
      "project": "sqlite",
      "scenario": "source-fetched_lib-fetched_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:44:02.374", "2026-09-23 20:44:03.165" ],
      "edges": {
        "resolve_sys": "warm",
        "realize_sys": "warm",
        "realize_hdr": "warm",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "undecided",
        "soname_matches_requirement": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "api_names_present": "holds"
      },
      "badges": { "install_surf": "holds", "link_mod": "undecided" },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "apt sqlite3.3.45.1",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_binding_python": "a dummy step: it performs nothing"
      },
      "names": {
        "mod_lang": { "label": "sqlite3 (210 names)", "from": "recorded" },
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "pm_lang": { "label": "pip", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "stub_lang": { "label": "_sqlite3*.so", "from": "declared" },
        "surf_lang": { "label": "sqlite3/__init__.py", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "bridge", "pm_lang", "src_lang",
        "stub_lang", "surf_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "4af838-ocaml",
      "project": "sqlite",
      "scenario": "source-fetched_lib-fetched_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:44:10.733", "2026-09-23 20:44:11.528" ],
      "edges": {
        "resolve_sys": "warm",
        "realize_sys": "warm",
        "realize_hdr": "warm",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "warm",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "apt sqlite3.3.45.1",
        "mod_lang": "opam sqlite3.5.4.1"
      },
      "unplaced": {},
      "names": {
        "mod_lang": { "label": "sqlite3 (1 modules)", "from": "recorded" },
        "stub_lang": { "label": "libsqlite3_stubs.a", "from": "recorded" },
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "bridge": { "label": "conf-sqlite3", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "surf_lang": { "label": "sqlite3.mli", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "src_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "4af838-python",
      "project": "sqlite",
      "scenario": "source-fetched_lib-fetched_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:44:10.733", "2026-09-23 20:44:11.552" ],
      "edges": {
        "resolve_sys": "warm",
        "realize_sys": "warm",
        "realize_hdr": "warm",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "undecided",
        "soname_matches_requirement": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "api_names_present": "holds"
      },
      "badges": { "install_surf": "holds", "link_mod": "undecided" },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "apt sqlite3.3.45.1",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_binding_python": "a dummy step: it performs nothing"
      },
      "names": {
        "mod_lang": { "label": "sqlite3 (210 names)", "from": "recorded" },
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "pm_lang": { "label": "pip", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "stub_lang": { "label": "_sqlite3*.so", "from": "declared" },
        "surf_lang": { "label": "sqlite3/__init__.py", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "bridge", "pm_lang", "src_lang",
        "stub_lang", "surf_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "d26e75-ocaml",
      "project": "llvm",
      "scenario": "source-fetched-19_lib-fetched_ocaml_binding-fetched-19-shared_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [],
      "span": [ "2026-08-20 13:32:37.682", "2026-08-20 13:32:39.247" ],
      "edges": {
        "resolve_sys": "ran",
        "realize_sys": "ran",
        "realize_hdr": "ran",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "ran",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "ran",
        "install_lang": "ran",
        "install_surf": "ran",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "xfail",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "dependencies_provided": "unevaluated",
        "signatures_agree": "unevaluated",
        "api_names_present": "unevaluated"
      },
      "badges": {
        "install_surf": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "nodes": {
        "src_sys": "F 19",
        "lib_sys": "apt llvm-19-dev.19",
        "mod_lang": "opam llvm.19-shared"
      },
      "unplaced": {},
      "names": {
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "llvm-19-dev", "from": "declared" },
        "lib_sys": { "label": "libLLVM.so", "from": "declared" },
        "hdr_sys": { "label": "Core.h", "from": "declared" },
        "src_sys": { "label": "llvm-project.git", "from": "declared" },
        "bridge": { "label": "conf-llvm-shared {= 19}", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "llvm", "from": "declared" },
        "stub_lang": { "label": "libllvm.a", "from": "declared" },
        "surf_lang": { "label": "llvm.mli", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "src_lang", "stub_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "c8fae6-ocaml",
      "project": "llvm",
      "scenario": "source-fetched-latest_lib-built-dev_ocaml_binding-built-dev_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "unrecorded",
        "build_hdr": "unrecorded",
        "stage": "unrecorded",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "unrecorded",
        "link_mod": "unrecorded",
        "pack": "absent",
        "probe_lib": "unrecorded",
        "run": "unrecorded",
        "run_packaged": "absent",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "unevaluated",
        "soname_matches_declaration": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_symbols_exported": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "dependencies_provided": "unevaluated",
        "signatures_agree": "unevaluated",
        "api_names_present": "unevaluated",
        "staged_interface_preserved": "unevaluated"
      },
      "badges": {
        "realize_sys": "unevaluated",
        "build_lib": "unevaluated",
        "stage": "unevaluated",
        "install_surf": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "nodes": { "src_sys": "F latest", "lib_sys": "B:d", "mod_lang": "B:d" },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "scan_source": "no edge for this action on the page",
        "configure": "no edge for this action on the page",
        "probe_lib_staged": "observes the staged copy, which has no observation edge"
      },
      "names": {
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "llvm-19-dev", "from": "declared" },
        "lib_sys": { "label": "libLLVM.so", "from": "declared" },
        "hdr_sys": { "label": "Core.h", "from": "declared" },
        "src_sys": { "label": "llvm-project.git", "from": "declared" },
        "bridge": { "label": "conf-llvm-shared {= 19}", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "llvm", "from": "declared" },
        "stub_lang": { "label": "libllvm.a", "from": "declared" },
        "surf_lang": { "label": "llvm.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "cap", "bridge", "pm_lang", "pkg_lang",
        "surf_lang", "consumer_package"
      ],
      "observed": {}
    },
    {
      "id": "9f4072-ocaml",
      "project": "llvm",
      "scenario": "source-fetched-arbipher_lib-built-dev_ocaml_binding-built-dev_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [],
      "span": [ "2026-08-20 13:32:23.400", "2026-08-20 13:32:37.227" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "ran",
        "stage": "ran",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "ran",
        "link_mod": "ran",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "ran",
        "run_packaged": "absent",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "unevaluated",
        "soname_matches_declaration": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_symbols_exported": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "dependencies_provided": "unevaluated",
        "signatures_agree": "unevaluated",
        "api_names_present": "unevaluated",
        "staged_interface_preserved": "unevaluated"
      },
      "badges": {
        "realize_sys": "unevaluated",
        "build_lib": "unevaluated",
        "stage": "unevaluated",
        "install_surf": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "nodes": {
        "src_sys": "F arbipher",
        "lib_sys": "B:d",
        "mod_lang": "B:d"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "scan_source": "no edge for this action on the page",
        "configure": "no edge for this action on the page",
        "probe_lib_staged": "observes the staged copy, which has no observation edge"
      },
      "names": {
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "llvm-19-dev", "from": "declared" },
        "lib_sys": { "label": "libLLVM.so", "from": "declared" },
        "hdr_sys": { "label": "Core.h", "from": "declared" },
        "src_sys": { "label": "llvm-project.git", "from": "declared" },
        "bridge": { "label": "conf-llvm-shared {= 19}", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "llvm", "from": "declared" },
        "stub_lang": { "label": "libllvm.a", "from": "declared" },
        "surf_lang": { "label": "llvm.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "cap", "bridge", "pm_lang", "pkg_lang",
        "surf_lang", "consumer_package"
      ],
      "observed": {}
    },
    {
      "id": "28a379-ocaml",
      "project": "tiny-full",
      "scenario": "source-vendored-stable_lib-vendored-stable_ocaml_binding-vendored-stable_python_binding-vendored-stable_python_binding-vendored-stable_app-vendored-stable_app-vendored-stable",
      "lang": "ocaml",
      "recorded_on": [],
      "span": [ "2026-08-16 17:15:56.681", "2026-08-16 17:15:56.682" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "warm",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "warm",
        "link_mod": "warm",
        "pack": "absent",
        "probe_lib": "warm",
        "run": "warm",
        "run_packaged": "absent",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "unevaluated",
        "soname_matches_declaration": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_symbols_exported": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "dependencies_provided": "unevaluated",
        "signatures_agree": "unevaluated",
        "api_names_present": "unevaluated"
      },
      "badges": {
        "realize_sys": "unevaluated",
        "build_lib": "unevaluated",
        "install_surf": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "nodes": { "src_sys": "V:s", "lib_sys": "V:s", "mod_lang": "V:s" },
      "unplaced": {
        "configure": "no edge for this action on the page",
        "scan_sources": "no edge for this action on the page"
      },
      "names": {
        "lib_sys": { "label": "libtiny.so.1", "from": "recorded" },
        "stub_lang": { "label": "libtiny_stubs.a", "from": "recorded" },
        "hdr_sys": { "label": "tiny.h", "from": "declared" },
        "surf_lang": { "label": "tiny.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "staged_sys", "cap", "bridge", "pm_lang",
        "pkg_lang", "surf_lang", "consumer_package"
      ],
      "observed": {}
    },
    {
      "id": "28a379-python",
      "project": "tiny-full",
      "scenario": "source-vendored-stable_lib-vendored-stable_ocaml_binding-vendored-stable_python_binding-vendored-stable_python_binding-vendored-stable_app-vendored-stable_app-vendored-stable",
      "lang": "python",
      "recorded_on": [],
      "span": [ "2026-08-16 17:15:56.681", "2026-08-16 17:15:56.682" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "warm",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "warm",
        "link_mod": "warm",
        "pack": "absent",
        "probe_lib": "warm",
        "run": "warm",
        "run_packaged": "absent",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "unevaluated",
        "soname_matches_declaration": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_symbols_exported": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "dependencies_provided": "unevaluated",
        "api_names_present": "unevaluated"
      },
      "badges": {
        "realize_sys": "unevaluated",
        "build_lib": "unevaluated",
        "install_surf": "unevaluated",
        "link_mod": "unevaluated"
      },
      "nodes": { "src_sys": "V:s", "lib_sys": "V:s", "mod_lang": "V:s" },
      "unplaced": {
        "configure": "no edge for this action on the page",
        "scan_sources": "no edge for this action on the page"
      },
      "names": {
        "lib_sys": { "label": "libtiny.so.1", "from": "recorded" },
        "stub_lang": {
          "label": "_native.cpython-314-x86_64-linux-gnu.so",
          "from": "recorded"
        },
        "mod_lang": { "label": "tiny_cext (3 names)", "from": "recorded" },
        "hdr_sys": { "label": "tiny.h", "from": "declared" },
        "surf_lang": { "label": "tiny_cext/__init__.py", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "staged_sys", "cap", "bridge", "pm_lang",
        "pkg_lang", "surf_lang", "consumer_package"
      ],
      "observed": {}
    },
    {
      "id": "614dda-ocaml",
      "project": "zarith",
      "scenario": "lib-fetched_ocaml_binding-built-dev_binding_source_ocaml-fetched-master",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:35:47.831", "2026-09-23 20:35:58.039" ],
      "edges": {
        "resolve_sys": "warm",
        "realize_sys": "warm",
        "realize_hdr": "warm",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "absent",
        "install_lang": "absent",
        "install_surf": "absent",
        "build_stub": "warm",
        "link_mod": "warm",
        "pack": "ran",
        "probe_lib": "warm",
        "run": "warm",
        "run_packaged": "absent",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "nodes": {
        "lib_sys": "apt libgmp-dev.2:6.3.0+dfsg",
        "src_lang": "F master",
        "mod_lang": "B:d"
      },
      "unplaced": {
        "fetch_binding_source_ocaml": "no edge for this action on the page"
      },
      "names": {
        "mod_lang": { "label": "zarith (4 modules)", "from": "recorded" },
        "stub_lang": { "label": "libzarith.a", "from": "recorded" },
        "lib_sys": { "label": "libgmp.so.10", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "libgmp-dev", "from": "declared" },
        "hdr_sys": { "label": "gmp.h", "from": "declared" },
        "bridge": { "label": "conf-gmp", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "zarith", "from": "declared" },
        "src_lang": { "label": "Zarith.git", "from": "declared" },
        "surf_lang": { "label": "zarith.mli", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "bridge", "pm_lang", "surf_lang",
        "consumer_package"
      ],
      "observed": {}
    },
    {
      "id": "4ea4a4-ocaml",
      "project": "zarith",
      "scenario": "lib-fetched_ocaml_binding-fetched_binding_source_ocaml-fetched-1.14",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-23 20:35:38.648", "2026-09-23 20:35:47.799" ],
      "edges": {
        "resolve_sys": "warm",
        "realize_sys": "warm",
        "realize_hdr": "warm",
        "realize_cap": "observed",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "observed",
        "depends": "warm",
        "conf_probe": "ran",
        "discover": "observed",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "warm",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "nodes": {
        "lib_sys": "apt libgmp-dev.2:6.3.0+dfsg",
        "src_lang": "F 1.14",
        "mod_lang": "opam zarith",
        "bridge": "installed 5",
        "pkg_sys": "2:6.3.0+dfsg-2ubuntu6.1",
        "cap": "gmp 6.3.0"
      },
      "unplaced": {},
      "names": {
        "mod_lang": { "label": "zarith (4 modules)", "from": "recorded" },
        "stub_lang": { "label": "libzarith.a", "from": "recorded" },
        "bridge": { "label": "conf-gmp", "from": "recorded" },
        "cap": { "label": "gmp.pc", "from": "recorded" },
        "pkg_sys": { "label": "libgmp-dev", "from": "recorded" },
        "lib_sys": { "label": "libgmp.so.10", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "hdr_sys": { "label": "gmp.h", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "zarith", "from": "declared" },
        "src_lang": { "label": "Zarith.git", "from": "declared" },
        "surf_lang": { "label": "zarith.mli", "from": "declared" }
      },
      "dim": [ "src_sys", "staged_sys", "src_lang", "consumer_artifact" ],
      "observed": {
        "depends": "zarith's depends names conf-gmp",
        "conf_probe": "conf-gmp's check: pkg-config --print-errors --exists gmp — holds",
        "depext": "conf-gmp maps to libgmp-dev",
        "resolve_sys": "installed here: libgmp-dev 2:6.3.0+dfsg-2ubuntu6.1",
        "realize_cap": "libgmp-dev ships /usr/lib/x86_64-linux-gnu/pkgconfig/gmp.pc",
        "discover": "pkg-config gmp → 6.3.0 in /usr/lib/x86_64-linux-gnu"
      }
    },
    {
      "id": "7a10f8-ocaml",
      "project": "cairo",
      "scenario": "source-fetched-1.18.0_lib-vendored-dev_ocaml_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-15 18:47:10.828", "2026-09-15 18:47:13.234" ],
      "edges": {
        "resolve_sys": "warm",
        "realize_sys": "warm",
        "realize_hdr": "warm",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "violated",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "violated"
      },
      "nodes": {
        "src_sys": "F 1.18.0",
        "lib_sys": "V:d",
        "mod_lang": "opam cairo2"
      },
      "unplaced": {
        "probe_lib": "observes the system package's library, which this world does not use"
      },
      "names": {
        "mod_lang": { "label": "cairo2 (1 modules)", "from": "recorded" },
        "stub_lang": { "label": "libcairo_stubs.a", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "libcairo2-dev", "from": "declared" },
        "hdr_sys": {
          "label": "cairo.h, cairo-ft.h, cairo-pdf.h, cairo-ps.h, cairo-svg.h",
          "from": "declared"
        },
        "src_sys": { "label": "cairo.git", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "cairo2", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "bridge", "src_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "7ac7f1-ocaml",
      "project": "cairo",
      "scenario": "source-fetched-1.18.0_lib-fetched_ocaml_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-15 18:47:12.829", "2026-09-15 18:47:13.152" ],
      "edges": {
        "resolve_sys": "warm",
        "realize_sys": "warm",
        "realize_hdr": "warm",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "violated",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "violated"
      },
      "nodes": {
        "src_sys": "F 1.18.0",
        "lib_sys": "apt libcairo2-dev.1.18.0",
        "mod_lang": "opam cairo2"
      },
      "unplaced": {},
      "names": {
        "mod_lang": { "label": "cairo2 (1 modules)", "from": "recorded" },
        "stub_lang": { "label": "libcairo_stubs.a", "from": "recorded" },
        "lib_sys": { "label": "libcairo.so.2", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "libcairo2-dev", "from": "declared" },
        "hdr_sys": {
          "label": "cairo.h, cairo-ft.h, cairo-pdf.h, cairo-ps.h, cairo-svg.h",
          "from": "declared"
        },
        "src_sys": { "label": "cairo.git", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "cairo2", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "bridge", "src_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "1406f0-ocaml",
      "project": "libffi",
      "scenario": "source-fetched-3.8.0_lib-vendored-dev_ocaml_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-15 18:47:11.994", "2026-09-15 18:47:12.287" ],
      "edges": {
        "resolve_sys": "warm",
        "realize_sys": "warm",
        "realize_hdr": "warm",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "holds",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "holds"
      },
      "nodes": {
        "src_sys": "F 3.8.0",
        "lib_sys": "V:d",
        "mod_lang": "opam ctypes-foreign"
      },
      "unplaced": {
        "probe_lib": "observes the system package's library, which this world does not use"
      },
      "names": {
        "mod_lang": {
          "label": "ctypes-foreign (9 modules)",
          "from": "recorded"
        },
        "stub_lang": {
          "label": "libctypes_foreign_stubs.a",
          "from": "recorded"
        },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "libffi-dev", "from": "declared" },
        "hdr_sys": { "label": "ffi.h, ffitarget.h", "from": "declared" },
        "src_sys": { "label": "libffi.git", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "ctypes-foreign", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "bridge", "src_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "0a184a-ocaml",
      "project": "libffi",
      "scenario": "source-fetched-3.8.0_lib-fetched_ocaml_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-15 18:47:11.643", "2026-09-15 18:47:11.964" ],
      "edges": {
        "resolve_sys": "warm",
        "realize_sys": "warm",
        "realize_hdr": "warm",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "holds",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "holds"
      },
      "nodes": {
        "src_sys": "F 3.8.0",
        "lib_sys": "apt libffi-dev.3.4.6",
        "mod_lang": "opam ctypes-foreign"
      },
      "unplaced": {},
      "names": {
        "mod_lang": {
          "label": "ctypes-foreign (9 modules)",
          "from": "recorded"
        },
        "stub_lang": {
          "label": "libctypes_foreign_stubs.a",
          "from": "recorded"
        },
        "lib_sys": { "label": "libffi.so.8", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "libffi-dev", "from": "declared" },
        "hdr_sys": { "label": "ffi.h, ffitarget.h", "from": "declared" },
        "src_sys": { "label": "libffi.git", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "ctypes-foreign", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "bridge", "src_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "657774-ocaml",
      "project": "zlib",
      "scenario": "source-fetched-1.3.1_lib-vendored-dev_ocaml_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-21 19:47:00.024", "2026-09-21 19:47:00.097" ],
      "edges": {
        "resolve_sys": "warm",
        "realize_sys": "warm",
        "realize_hdr": "warm",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "warm",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "undecided",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "nodes": {
        "src_sys": "F 1.3.1",
        "lib_sys": "V:d",
        "mod_lang": "opam camlzip"
      },
      "unplaced": {
        "probe_lib": "observes the system package's library, which this world does not use"
      },
      "names": {
        "mod_lang": { "label": "zip (3 modules)", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "zlib1g-dev", "from": "declared" },
        "lib_sys": { "label": "libz.so.1", "from": "declared" },
        "hdr_sys": { "label": "zlib.h, zconf.h", "from": "declared" },
        "src_sys": { "label": "zlib.git", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "camlzip", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "bridge", "src_lang", "stub_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "d668a4-ocaml",
      "project": "zlib",
      "scenario": "source-fetched-1.3.1_lib-fetched_ocaml_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-21 19:46:59.941", "2026-09-21 19:47:00.004" ],
      "edges": {
        "resolve_sys": "warm",
        "realize_sys": "warm",
        "realize_hdr": "warm",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "warm",
        "run": "absent",
        "run_packaged": "warm",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "undecided",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "undecided",
        "dependencies_provided": "holds",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "nodes": {
        "src_sys": "F 1.3.1",
        "lib_sys": "apt zlib1g-dev.1:1.3.dfsg",
        "mod_lang": "opam camlzip"
      },
      "unplaced": {},
      "names": {
        "mod_lang": { "label": "zip (3 modules)", "from": "recorded" },
        "lib_sys": { "label": "libz.so.1", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "zlib1g-dev", "from": "declared" },
        "hdr_sys": { "label": "zlib.h, zconf.h", "from": "declared" },
        "src_sys": { "label": "zlib.git", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "camlzip", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "bridge", "src_lang", "stub_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "ff020b-ocaml",
      "project": "zstd",
      "scenario": "source-fetched-1.5.7_lib-vendored-dev_ocaml_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [],
      "span": [ "2026-08-20 16:56:24.762", "2026-08-20 16:56:25.883" ],
      "edges": {
        "resolve_sys": "ran",
        "realize_sys": "ran",
        "realize_hdr": "ran",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "ran",
        "install_lang": "ran",
        "install_surf": "ran",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "fail",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "dependencies_provided": "unevaluated",
        "signatures_agree": "unevaluated",
        "api_names_present": "unevaluated"
      },
      "badges": {
        "install_surf": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "nodes": {
        "src_sys": "F 1.5.7",
        "lib_sys": "V:d",
        "mod_lang": "opam zstd"
      },
      "unplaced": {
        "probe_lib": "observes the system package's library, which this world does not use"
      },
      "names": {
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "libzstd-dev", "from": "declared" },
        "lib_sys": { "label": "libzstd.so.1", "from": "declared" },
        "hdr_sys": { "label": "zstd.h, zstd_errors.h", "from": "declared" },
        "src_sys": { "label": "zstd.git", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "zstd", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "bridge", "src_lang", "stub_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "ff7b9d-ocaml",
      "project": "zstd",
      "scenario": "source-fetched-1.5.7_lib-fetched_ocaml_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [],
      "span": [ "2026-08-20 16:56:22.725", "2026-08-20 16:56:24.044" ],
      "edges": {
        "resolve_sys": "ran",
        "realize_sys": "ran",
        "realize_hdr": "ran",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "absent",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "ran",
        "install_lang": "ran",
        "install_surf": "ran",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "dependencies_provided": "unevaluated",
        "signatures_agree": "unevaluated",
        "api_names_present": "unevaluated"
      },
      "badges": {
        "install_surf": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "nodes": {
        "src_sys": "F 1.5.7",
        "lib_sys": "apt libzstd-dev.1.5.5+dfsg2",
        "mod_lang": "opam zstd"
      },
      "unplaced": {},
      "names": {
        "mod_lang": { "label": "zstd (1 modules)", "from": "recorded" },
        "lib_sys": { "label": "libzstd.so.1", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "libzstd-dev", "from": "declared" },
        "hdr_sys": { "label": "zstd.h, zstd_errors.h", "from": "declared" },
        "src_sys": { "label": "zstd.git", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "zstd", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "bridge", "src_lang", "stub_lang",
        "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "7b508c-ocaml",
      "project": "ssl",
      "scenario": "source-fetched_lib-fetched_ocaml_binding-fetched-0.6.0_app-vendored-stable",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-15 18:47:33.719", "2026-09-15 18:47:40.599" ],
      "edges": {
        "resolve_sys": "warm",
        "realize_sys": "warm",
        "realize_hdr": "warm",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "ran",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "ran",
        "install_lang": "ran",
        "install_surf": "ran",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "fail",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "holds",
        "dependencies_provided": "violated",
        "signatures_agree": "undecided",
        "api_names_present": "violated"
      },
      "badges": {
        "install_surf": "violated",
        "build_stub": "undecided",
        "link_mod": "violated"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "apt libssl-dev.3.0.13",
        "mod_lang": "opam ssl.0.6.0"
      },
      "unplaced": {
        "probe_app_ocaml": "no edge for this action on the page"
      },
      "names": {
        "stub_lang": { "label": "libssl_stubs.a", "from": "recorded" },
        "lib_sys": { "label": "libssl.so.3", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "libssl-dev", "from": "declared" },
        "hdr_sys": { "label": "ssl.h", "from": "declared" },
        "src_sys": { "label": "openssl.git", "from": "declared" },
        "bridge": { "label": "conf-libssl", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "ssl", "from": "declared" },
        "surf_lang": { "label": "ssl.mli", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "src_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "8f247d-ocaml",
      "project": "ssl",
      "scenario": "source-fetched_lib-fetched_ocaml_binding-fetched-0.7.0_app-vendored-stable",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-15 18:47:40.625", "2026-09-15 18:47:44.436" ],
      "edges": {
        "resolve_sys": "warm",
        "realize_sys": "warm",
        "realize_hdr": "warm",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "ran",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "ran",
        "install_lang": "ran",
        "install_surf": "ran",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "fail",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "holds",
        "dependencies_provided": "violated",
        "signatures_agree": "undecided",
        "api_names_present": "holds"
      },
      "badges": {
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "violated"
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "apt libssl-dev.3.0.13",
        "mod_lang": "opam ssl.0.7.0"
      },
      "unplaced": {
        "probe_app_ocaml": "no edge for this action on the page"
      },
      "names": {
        "stub_lang": { "label": "libssl_stubs.a", "from": "recorded" },
        "lib_sys": { "label": "libssl.so.3", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "libssl-dev", "from": "declared" },
        "hdr_sys": { "label": "ssl.h", "from": "declared" },
        "src_sys": { "label": "openssl.git", "from": "declared" },
        "bridge": { "label": "conf-libssl", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "ssl", "from": "declared" },
        "surf_lang": { "label": "ssl.mli", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "src_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "0dc978-ocaml",
      "project": "torch",
      "scenario": "lib-fetched-2.1.2_ocaml_binding-fetched-v0.17.0_binding_source_ocaml-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-08-31 14:28:25.952", "2026-08-31 14:29:23.656" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "xfail",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "xfail",
        "install_lang": "xfail",
        "install_surf": "xfail",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "warm",
        "run": "absent",
        "run_packaged": "xfail",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "dependencies_provided": "unevaluated",
        "signatures_agree": "unevaluated",
        "api_names_present": "unevaluated"
      },
      "badges": {
        "install_surf": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "nodes": {
        "lib_sys": "opam libtorch.2.1.2",
        "src_lang": "F",
        "mod_lang": "opam torch.v0.17.0"
      },
      "unplaced": {
        "fetch_lib": "the library comes from a language package manager: no edge from there"
      },
      "names": {
        "lib_sys": { "label": "libtorch_cpu.so", "from": "recorded" },
        "hdr_sys": { "label": "torch.h", "from": "declared" },
        "bridge": {
          "label": "depext: libtorch >= 2.1.0 & < 2.2.0",
          "from": "declared"
        },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "torch", "from": "declared" },
        "src_lang": { "label": "torch.git", "from": "declared" },
        "stub_lang": { "label": "libtorch_core_stubs.a", "from": "declared" },
        "surf_lang": { "label": "torch.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "src_sys", "hdr_sys", "staged_sys", "cap",
        "src_lang", "stub_lang", "consumer_artifact"
      ],
      "observed": {}
    },
    {
      "id": "e1d373-ocaml",
      "project": "torch",
      "scenario": "lib-fetched-2.1.2_ocaml_binding-fetched-v0.17.0-canary1_binding_source_ocaml-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-08-31 14:29:23.685", "2026-08-31 14:29:25.523" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "absent",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "ran",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "ran",
        "install_lang": "ran",
        "install_surf": "ran",
        "build_stub": "absent",
        "link_mod": "absent",
        "pack": "absent",
        "probe_lib": "warm",
        "run": "absent",
        "run_packaged": "warm",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "dependencies_provided": "unevaluated",
        "signatures_agree": "unevaluated",
        "api_names_present": "unevaluated"
      },
      "badges": {
        "install_surf": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "nodes": {
        "lib_sys": "opam libtorch.2.1.2",
        "src_lang": "F",
        "mod_lang": "opam torch.v0.17.0-canary1"
      },
      "unplaced": {
        "fetch_lib": "the library comes from a language package manager: no edge from there"
      },
      "names": {
        "lib_sys": { "label": "libtorch_cpu.so", "from": "recorded" },
        "hdr_sys": { "label": "torch.h", "from": "declared" },
        "bridge": {
          "label": "depext: libtorch >= 2.1.0 & < 2.2.0",
          "from": "declared"
        },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "torch", "from": "declared" },
        "src_lang": { "label": "torch.git", "from": "declared" },
        "stub_lang": { "label": "libtorch_core_stubs.a", "from": "declared" },
        "surf_lang": { "label": "torch.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "src_sys", "hdr_sys", "staged_sys", "cap",
        "src_lang", "stub_lang", "consumer_artifact"
      ],
      "observed": {}
    }
  ],
  "cases": {
    "conf": "4ea4a4-ocaml",
    "built": "08b7dd-ocaml",
    "unified": "0dc978-ocaml",
    "none": "c2ff32-python"
  }
});

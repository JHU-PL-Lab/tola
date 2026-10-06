(window.CANARY_RUNS = window.CANARY_RUNS || []).push(
{
  "machine": "wsl_ubuntu",
  "generated": "2026-10-06 18:35",
  "views": [
    {
      "id": "be0605-ocaml",
      "case": "sqlite-ocaml-opam-built",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:19.687", "2026-10-06 18:35:20.571" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "warm",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds",
        "gate_admits_the_world": "undecided"
      },
      "badges": {
        "build_lib": "violated",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "pm_sys", "pkg_sys", "staged_sys", "cap", "consumer_artifact"
      ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-built-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (1 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_source-fetched_lib-built-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libsqlite3_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_stub_source-fetched_lib-built-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "no_build_paths_in_installed_library",
        "source_is_declared_ref", "build_tree_configured_for_source",
        "behavior_matches", "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": { "lib_sys": "270 exports", "stub_lang": "58 required" },
      "row": {
        "sort": "sqlite|be0605-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-be0605-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=be0605-ocaml%40wsl_ubuntu\" data-key=\"be0605-ocaml@wsl_ubuntu\"><b>sqlite</b> be0605-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — B:s\">libsqlite3.so.0 <span class=\"rt-x\">270 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-bad\" title=\"declared_symbols_exported: violated — blame: version (one declared value, several version points — spec)\">✗</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:s\">libsqlite3.so.0</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libsqlite3_stubs.a\">libsqlite3_stubs.a <span class=\"rt-x\">58 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:s\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (1 modules) — opam sqlite3.5.1.0\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-sqlite3\">conf-sqlite3</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-gap\" title=\"gate_admits_the_world: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (1 modules) — opam sqlite3.5.1.0\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3.mli\">sqlite3.mli</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds",
        "gate_admits_the_world": "unavailable"
      },
      "blames": {
        "declared_symbols_exported": "version",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence",
        "gate_admits_the_world": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "built",
        "cooperation": "gated_local",
        "character": "⚠ bridge still gates, against a system this world does not use"
      },
      "placeholders": {
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "be0605-python",
      "case": "sqlite-python-pip-built",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:19.687", "2026-10-06 18:35:20.595" ],
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
        "install_lang": "included",
        "install_surf": "included",
        "build_stub": "absent",
        "link_mod": "included",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "undecided",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "undecided",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided"
      },
      "badges": {
        "build_lib": "violated",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "B:s",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
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
        "pm_lang", "src_lang", "consumer_artifact"
      ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-built-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (210 names)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/python/inspect_source-fetched_lib-built-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "pip",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "_sqlite3*.so",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3/__init__.py",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "repack_preserves_api", "repack_complete",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
      "counts": { "lib_sys": "270 exports" },
      "row": {
        "sort": "sqlite|be0605-python|wsl_ubuntu",
        "head": "<tr id=\"row-be0605-python@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=be0605-python%40wsl_ubuntu\" data-key=\"be0605-python@wsl_ubuntu\"><b>sqlite</b> be0605-python</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — B:s\">libsqlite3.so.0 <span class=\"rt-x\">270 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-bad\" title=\"declared_symbols_exported: violated — blame: version (one declared value, several version points — spec)\">✗</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:s\">libsqlite3.so.0</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art rt-off\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: n/a\">n/a</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: absent\">—</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"_sqlite3*.so\">_sqlite3*.so</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:s\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"dependencies_provided: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_symbols_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"soname_matches_requirement: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: included\">∈</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"pip\">pip</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-dim\" title=\"resolve_lang: absent\">—</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-dim\" title=\"depends: absent\">—</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: n/a\">n/a</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-dim\" title=\"install_lang, install_surf: included\">∈</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3/__init__.py\">sqlite3/__init__.py</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "unavailable",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "unavailable",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "unavailable",
        "signatures_agree": "n/a",
        "dependencies_provided": "unavailable",
        "gate_admits_the_world": "n/a"
      },
      "blames": {
        "declared_symbols_exported": "version",
        "required_symbols_exported": "evidence",
        "soname_matches_requirement": "evidence",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "evidence",
        "dependencies_provided": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cext",
        "lang_side": "pip",
        "native_side": "built",
        "cooperation": "no_pm",
        "character": "no package manager stands between these two artifacts"
      },
      "placeholders": {}
    },
    {
      "id": "df925e-ocaml",
      "case": "sqlite-ocaml-opam-built",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:29.432", "2026-10-06 18:35:30.352" ],
      "edges": {
        "resolve_sys": "absent",
        "realize_sys": "absent",
        "realize_hdr": "absent",
        "realize_cap": "not_ours",
        "build_lib": "ran",
        "build_hdr": "absent",
        "stage": "absent",
        "depext": "not_ours",
        "depends": "warm",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds",
        "gate_admits_the_world": "undecided"
      },
      "badges": {
        "build_lib": "violated",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "pm_sys", "pkg_sys", "staged_sys", "cap", "consumer_artifact"
      ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-built-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (1 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_source-fetched_lib-built-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libsqlite3_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_stub_source-fetched_lib-built-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "no_build_paths_in_installed_library",
        "source_is_declared_ref", "build_tree_configured_for_source",
        "behavior_matches", "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": { "lib_sys": "270 exports", "stub_lang": "62 required" },
      "row": {
        "sort": "sqlite|df925e-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-df925e-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=df925e-ocaml%40wsl_ubuntu\" data-key=\"df925e-ocaml@wsl_ubuntu\"><b>sqlite</b> df925e-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — B:s\">libsqlite3.so.0 <span class=\"rt-x\">270 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-bad\" title=\"declared_symbols_exported: violated — blame: version (one declared value, several version points — spec)\">✗</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:s\">libsqlite3.so.0</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libsqlite3_stubs.a\">libsqlite3_stubs.a <span class=\"rt-x\">62 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:s\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (1 modules) — opam sqlite3.5.4.1\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-sqlite3\">conf-sqlite3</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-gap\" title=\"gate_admits_the_world: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (1 modules) — opam sqlite3.5.4.1\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3.mli\">sqlite3.mli</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds",
        "gate_admits_the_world": "unavailable"
      },
      "blames": {
        "declared_symbols_exported": "version",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence",
        "gate_admits_the_world": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "built",
        "cooperation": "gated_local",
        "character": "⚠ bridge still gates, against a system this world does not use"
      },
      "placeholders": {
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "df925e-python",
      "case": "sqlite-python-pip-built",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:29.432", "2026-10-06 18:35:30.376" ],
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
        "install_lang": "included",
        "install_surf": "included",
        "build_stub": "absent",
        "link_mod": "included",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "undecided",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "undecided",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided"
      },
      "badges": {
        "build_lib": "violated",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "B:s",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
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
        "pm_lang", "src_lang", "consumer_artifact"
      ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-built-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (210 names)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/python/inspect_source-fetched_lib-built-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "pip",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "_sqlite3*.so",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3/__init__.py",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "repack_preserves_api", "repack_complete",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
      "counts": { "lib_sys": "270 exports" },
      "row": {
        "sort": "sqlite|df925e-python|wsl_ubuntu",
        "head": "<tr id=\"row-df925e-python@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=df925e-python%40wsl_ubuntu\" data-key=\"df925e-python@wsl_ubuntu\"><b>sqlite</b> df925e-python</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — B:s\">libsqlite3.so.0 <span class=\"rt-x\">270 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-bad\" title=\"declared_symbols_exported: violated — blame: version (one declared value, several version points — spec)\">✗</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:s\">libsqlite3.so.0</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art rt-off\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: n/a\">n/a</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: absent\">—</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"_sqlite3*.so\">_sqlite3*.so</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:s\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"dependencies_provided: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_symbols_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"soname_matches_requirement: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: included\">∈</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"pip\">pip</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-dim\" title=\"resolve_lang: absent\">—</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-dim\" title=\"depends: absent\">—</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: n/a\">n/a</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-dim\" title=\"install_lang, install_surf: included\">∈</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3/__init__.py\">sqlite3/__init__.py</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "unavailable",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "unavailable",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "unavailable",
        "signatures_agree": "n/a",
        "dependencies_provided": "unavailable",
        "gate_admits_the_world": "n/a"
      },
      "blames": {
        "declared_symbols_exported": "version",
        "required_symbols_exported": "evidence",
        "soname_matches_requirement": "evidence",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "evidence",
        "dependencies_provided": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cext",
        "lang_side": "pip",
        "native_side": "built",
        "cooperation": "no_pm",
        "character": "no package manager stands between these two artifacts"
      },
      "placeholders": {}
    },
    {
      "id": "bf7656-ocaml",
      "case": "sqlite-ocaml-opam-staged",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:21.421", "2026-10-06 18:35:22.322" ],
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
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds",
        "staged_interface_preserved": "holds",
        "gate_admits_the_world": "undecided"
      },
      "badges": {
        "build_lib": "violated",
        "stage": "holds",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "stage": [
          [ "staged_interface_preserved", "checked" ],
          [ "no_build_paths_in_installed_library", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "stage": [ 1, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "staged_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "bridge": { "label": "conf-sqlite3", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "surf_lang": { "label": "sqlite3.mli", "from": "declared" }
      },
      "dim": [ "pm_sys", "pkg_sys", "cap", "consumer_artifact" ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-installed-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (1 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_source-fetched_lib-installed-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libsqlite3_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_stub_source-fetched_lib-installed-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "staged_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/probe_lib_staged/inspect_source-fetched_lib-installed-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "no_build_paths_in_installed_library",
        "source_is_declared_ref", "build_tree_configured_for_source",
        "behavior_matches", "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": {
        "lib_sys": "270 exports",
        "stub_lang": "58 required",
        "staged_sys": "270 exports"
      },
      "row": {
        "sort": "sqlite|bf7656-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-bf7656-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=bf7656-ocaml%40wsl_ubuntu\" data-key=\"bf7656-ocaml@wsl_ubuntu\"><b>sqlite</b> bf7656-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — I:s\">libsqlite3.so.0 <span class=\"rt-x\">270 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-bad\" title=\"declared_symbols_exported: violated — blame: version (one declared value, several version points — spec)\">✗</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:s\">libsqlite3.so.0</td>",
          "install_lib|p|stage": "<td class=\"rt-p rt-warm\" title=\"stage: warm\">✓</td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0\">libsqlite3.so.0 <span class=\"rt-x\">270 exports</span></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-c rt-ok\" title=\"staged_interface_preserved: holds\">✓</td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-off\"></td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libsqlite3_stubs.a\">libsqlite3_stubs.a <span class=\"rt-x\">58 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:s\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (1 modules) — opam sqlite3.5.1.0\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-sqlite3\">conf-sqlite3</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-gap\" title=\"gate_admits_the_world: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (1 modules) — opam sqlite3.5.1.0\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3.mli\">sqlite3.mli</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds",
        "staged_interface_preserved": "holds",
        "gate_admits_the_world": "unavailable"
      },
      "blames": {
        "declared_symbols_exported": "version",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence",
        "gate_admits_the_world": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "staged",
        "cooperation": "gated_local",
        "character": "⚠ bridge still gates, against a system this world does not use"
      },
      "placeholders": {
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "bf7656-python",
      "case": "sqlite-python-pip-staged",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:21.421", "2026-10-06 18:35:22.345" ],
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
        "install_lang": "included",
        "install_surf": "included",
        "build_stub": "absent",
        "link_mod": "included",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "undecided",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "undecided",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "staged_interface_preserved": "holds"
      },
      "badges": {
        "build_lib": "violated",
        "stage": "holds",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "stage": [
          [ "staged_interface_preserved", "checked" ],
          [ "no_build_paths_in_installed_library", "placeholder" ]
        ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "stage": [ 1, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "I:s",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "probe_lib_staged": "observes the staged copy, which has no observation edge",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (210 names)", "from": "recorded" },
        "staged_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
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
        "src_lang", "consumer_artifact"
      ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-installed-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (210 names)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/python/inspect_source-fetched_lib-installed-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "staged_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/probe_lib_staged/inspect_source-fetched_lib-installed-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "pip",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "_sqlite3*.so",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3/__init__.py",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "repack_preserves_api", "repack_complete",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
      "counts": { "lib_sys": "270 exports", "staged_sys": "270 exports" },
      "row": {
        "sort": "sqlite|bf7656-python|wsl_ubuntu",
        "head": "<tr id=\"row-bf7656-python@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=bf7656-python%40wsl_ubuntu\" data-key=\"bf7656-python@wsl_ubuntu\"><b>sqlite</b> bf7656-python</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — I:s\">libsqlite3.so.0 <span class=\"rt-x\">270 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-bad\" title=\"declared_symbols_exported: violated — blame: version (one declared value, several version points — spec)\">✗</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:s\">libsqlite3.so.0</td>",
          "install_lib|p|stage": "<td class=\"rt-p rt-warm\" title=\"stage: warm\">✓</td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0\">libsqlite3.so.0 <span class=\"rt-x\">270 exports</span></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-c rt-ok\" title=\"staged_interface_preserved: holds\">✓</td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-off\"></td>",
          "build_binding|n|src_lang": "<td class=\"rt-art rt-off\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: n/a\">n/a</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: absent\">—</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"_sqlite3*.so\">_sqlite3*.so</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:s\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"dependencies_provided: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_symbols_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"soname_matches_requirement: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: included\">∈</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"pip\">pip</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-dim\" title=\"resolve_lang: absent\">—</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-dim\" title=\"depends: absent\">—</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: n/a\">n/a</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-dim\" title=\"install_lang, install_surf: included\">∈</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3/__init__.py\">sqlite3/__init__.py</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "unavailable",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "unavailable",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "unavailable",
        "signatures_agree": "n/a",
        "dependencies_provided": "unavailable",
        "staged_interface_preserved": "holds",
        "gate_admits_the_world": "n/a"
      },
      "blames": {
        "declared_symbols_exported": "version",
        "required_symbols_exported": "evidence",
        "soname_matches_requirement": "evidence",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "evidence",
        "dependencies_provided": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cext",
        "lang_side": "pip",
        "native_side": "staged",
        "cooperation": "no_pm",
        "character": "no package manager stands between these two artifacts"
      },
      "placeholders": {}
    },
    {
      "id": "e35b2b-ocaml",
      "case": "sqlite-ocaml-opam-staged",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:31.190", "2026-10-06 18:35:32.092" ],
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
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds",
        "staged_interface_preserved": "holds",
        "gate_admits_the_world": "undecided"
      },
      "badges": {
        "build_lib": "violated",
        "stage": "holds",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "stage": [
          [ "staged_interface_preserved", "checked" ],
          [ "no_build_paths_in_installed_library", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "stage": [ 1, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "staged_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "bridge": { "label": "conf-sqlite3", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "surf_lang": { "label": "sqlite3.mli", "from": "declared" }
      },
      "dim": [ "pm_sys", "pkg_sys", "cap", "consumer_artifact" ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-installed-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (1 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_source-fetched_lib-installed-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libsqlite3_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_stub_source-fetched_lib-installed-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "staged_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/probe_lib_staged/inspect_source-fetched_lib-installed-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "no_build_paths_in_installed_library",
        "source_is_declared_ref", "build_tree_configured_for_source",
        "behavior_matches", "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": {
        "lib_sys": "270 exports",
        "stub_lang": "62 required",
        "staged_sys": "270 exports"
      },
      "row": {
        "sort": "sqlite|e35b2b-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-e35b2b-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=e35b2b-ocaml%40wsl_ubuntu\" data-key=\"e35b2b-ocaml@wsl_ubuntu\"><b>sqlite</b> e35b2b-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — I:s\">libsqlite3.so.0 <span class=\"rt-x\">270 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-bad\" title=\"declared_symbols_exported: violated — blame: version (one declared value, several version points — spec)\">✗</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:s\">libsqlite3.so.0</td>",
          "install_lib|p|stage": "<td class=\"rt-p rt-warm\" title=\"stage: warm\">✓</td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0\">libsqlite3.so.0 <span class=\"rt-x\">270 exports</span></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-c rt-ok\" title=\"staged_interface_preserved: holds\">✓</td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-off\"></td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libsqlite3_stubs.a\">libsqlite3_stubs.a <span class=\"rt-x\">62 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:s\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (1 modules) — opam sqlite3.5.4.1\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-sqlite3\">conf-sqlite3</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-gap\" title=\"gate_admits_the_world: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (1 modules) — opam sqlite3.5.4.1\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3.mli\">sqlite3.mli</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds",
        "staged_interface_preserved": "holds",
        "gate_admits_the_world": "unavailable"
      },
      "blames": {
        "declared_symbols_exported": "version",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence",
        "gate_admits_the_world": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "staged",
        "cooperation": "gated_local",
        "character": "⚠ bridge still gates, against a system this world does not use"
      },
      "placeholders": {
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "e35b2b-python",
      "case": "sqlite-python-pip-staged",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:31.190", "2026-10-06 18:35:32.115" ],
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
        "install_lang": "included",
        "install_surf": "included",
        "build_stub": "absent",
        "link_mod": "included",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "undecided",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "undecided",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "staged_interface_preserved": "holds"
      },
      "badges": {
        "build_lib": "violated",
        "stage": "holds",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "stage": [
          [ "staged_interface_preserved", "checked" ],
          [ "no_build_paths_in_installed_library", "placeholder" ]
        ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "stage": [ 1, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "I:s",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "probe_lib_staged": "observes the staged copy, which has no observation edge",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (210 names)", "from": "recorded" },
        "staged_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
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
        "src_lang", "consumer_artifact"
      ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-installed-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (210 names)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/python/inspect_source-fetched_lib-installed-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "staged_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/probe_lib_staged/inspect_source-fetched_lib-installed-stable_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "pip",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "_sqlite3*.so",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3/__init__.py",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "repack_preserves_api", "repack_complete",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
      "counts": { "lib_sys": "270 exports", "staged_sys": "270 exports" },
      "row": {
        "sort": "sqlite|e35b2b-python|wsl_ubuntu",
        "head": "<tr id=\"row-e35b2b-python@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=e35b2b-python%40wsl_ubuntu\" data-key=\"e35b2b-python@wsl_ubuntu\"><b>sqlite</b> e35b2b-python</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — I:s\">libsqlite3.so.0 <span class=\"rt-x\">270 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-bad\" title=\"declared_symbols_exported: violated — blame: version (one declared value, several version points — spec)\">✗</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:s\">libsqlite3.so.0</td>",
          "install_lib|p|stage": "<td class=\"rt-p rt-warm\" title=\"stage: warm\">✓</td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0\">libsqlite3.so.0 <span class=\"rt-x\">270 exports</span></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-c rt-ok\" title=\"staged_interface_preserved: holds\">✓</td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-off\"></td>",
          "build_binding|n|src_lang": "<td class=\"rt-art rt-off\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: n/a\">n/a</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: absent\">—</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"_sqlite3*.so\">_sqlite3*.so</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:s\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"dependencies_provided: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_symbols_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"soname_matches_requirement: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: included\">∈</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"pip\">pip</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-dim\" title=\"resolve_lang: absent\">—</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-dim\" title=\"depends: absent\">—</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: n/a\">n/a</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-dim\" title=\"install_lang, install_surf: included\">∈</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3/__init__.py\">sqlite3/__init__.py</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "violated",
        "required_symbols_exported": "unavailable",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "unavailable",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "unavailable",
        "signatures_agree": "n/a",
        "dependencies_provided": "unavailable",
        "staged_interface_preserved": "holds",
        "gate_admits_the_world": "n/a"
      },
      "blames": {
        "declared_symbols_exported": "version",
        "required_symbols_exported": "evidence",
        "soname_matches_requirement": "evidence",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "evidence",
        "dependencies_provided": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cext",
        "lang_side": "pip",
        "native_side": "staged",
        "cooperation": "no_pm",
        "character": "no package manager stands between these two artifacts"
      },
      "placeholders": {}
    },
    {
      "id": "08b7dd-ocaml",
      "case": "sqlite-ocaml-opam-built",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:12.537", "2026-10-06 18:35:18.726" ],
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
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds",
        "gate_admits_the_world": "undecided"
      },
      "badges": {
        "build_lib": "partial",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "pm_sys", "pkg_sys", "staged_sys", "cap", "consumer_artifact"
      ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-built-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (1 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_source-fetched_lib-built-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libsqlite3_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_stub_source-fetched_lib-built-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "no_build_paths_in_installed_library",
        "source_is_declared_ref", "build_tree_configured_for_source",
        "behavior_matches", "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": { "lib_sys": "272 exports", "stub_lang": "58 required" },
      "row": {
        "sort": "sqlite|08b7dd-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-08b7dd-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=08b7dd-ocaml%40wsl_ubuntu\" data-key=\"08b7dd-ocaml@wsl_ubuntu\"><b>sqlite</b> 08b7dd-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — B:d\">libsqlite3.so.0 <span class=\"rt-x\">272 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"declared_symbols_exported: holds\">✓</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:d\">libsqlite3.so.0</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libsqlite3_stubs.a\">libsqlite3_stubs.a <span class=\"rt-x\">58 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:d\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (1 modules) — opam sqlite3.5.1.0\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-ok\" title=\"resolve_lang: ran\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-ok\" title=\"depends: ran\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-sqlite3\">conf-sqlite3</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-gap\" title=\"gate_admits_the_world: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-ok\" title=\"install_lang, install_surf: ran\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (1 modules) — opam sqlite3.5.1.0\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3.mli\">sqlite3.mli</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds",
        "gate_admits_the_world": "unavailable"
      },
      "blames": {
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence",
        "gate_admits_the_world": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "built",
        "cooperation": "gated_local",
        "character": "⚠ bridge still gates, against a system this world does not use"
      },
      "placeholders": {
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "08b7dd-python",
      "case": "sqlite-python-pip-built",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:12.537", "2026-10-06 18:35:18.750" ],
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
        "install_lang": "included",
        "install_surf": "included",
        "build_stub": "absent",
        "link_mod": "included",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "undecided",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "undecided",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided"
      },
      "badges": {
        "build_lib": "partial",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "B:d",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
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
        "pm_lang", "src_lang", "consumer_artifact"
      ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-built-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (210 names)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/python/inspect_source-fetched_lib-built-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "pip",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "_sqlite3*.so",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3/__init__.py",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "repack_preserves_api", "repack_complete",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
      "counts": { "lib_sys": "272 exports" },
      "row": {
        "sort": "sqlite|08b7dd-python|wsl_ubuntu",
        "head": "<tr id=\"row-08b7dd-python@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=08b7dd-python%40wsl_ubuntu\" data-key=\"08b7dd-python@wsl_ubuntu\"><b>sqlite</b> 08b7dd-python</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — B:d\">libsqlite3.so.0 <span class=\"rt-x\">272 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"declared_symbols_exported: holds\">✓</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:d\">libsqlite3.so.0</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art rt-off\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: n/a\">n/a</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: absent\">—</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"_sqlite3*.so\">_sqlite3*.so</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:d\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"dependencies_provided: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_symbols_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"soname_matches_requirement: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: included\">∈</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"pip\">pip</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-dim\" title=\"resolve_lang: absent\">—</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-dim\" title=\"depends: absent\">—</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: n/a\">n/a</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-dim\" title=\"install_lang, install_surf: included\">∈</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3/__init__.py\">sqlite3/__init__.py</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "unavailable",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "unavailable",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "unavailable",
        "signatures_agree": "n/a",
        "dependencies_provided": "unavailable",
        "gate_admits_the_world": "n/a"
      },
      "blames": {
        "required_symbols_exported": "evidence",
        "soname_matches_requirement": "evidence",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "evidence",
        "dependencies_provided": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cext",
        "lang_side": "pip",
        "native_side": "built",
        "cooperation": "no_pm",
        "character": "no package manager stands between these two artifacts"
      },
      "placeholders": {}
    },
    {
      "id": "b8e9cb-ocaml",
      "case": "sqlite-ocaml-opam-built",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:22.357", "2026-10-06 18:35:28.448" ],
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
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds",
        "gate_admits_the_world": "undecided"
      },
      "badges": {
        "build_lib": "partial",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "pm_sys", "pkg_sys", "staged_sys", "cap", "consumer_artifact"
      ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-built-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (1 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_source-fetched_lib-built-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libsqlite3_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_stub_source-fetched_lib-built-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "no_build_paths_in_installed_library",
        "source_is_declared_ref", "build_tree_configured_for_source",
        "behavior_matches", "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": { "lib_sys": "272 exports", "stub_lang": "62 required" },
      "row": {
        "sort": "sqlite|b8e9cb-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-b8e9cb-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=b8e9cb-ocaml%40wsl_ubuntu\" data-key=\"b8e9cb-ocaml@wsl_ubuntu\"><b>sqlite</b> b8e9cb-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — B:d\">libsqlite3.so.0 <span class=\"rt-x\">272 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"declared_symbols_exported: holds\">✓</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:d\">libsqlite3.so.0</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libsqlite3_stubs.a\">libsqlite3_stubs.a <span class=\"rt-x\">62 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:d\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (1 modules) — opam sqlite3.5.4.1\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-ok\" title=\"resolve_lang: ran\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-ok\" title=\"depends: ran\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-sqlite3\">conf-sqlite3</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-gap\" title=\"gate_admits_the_world: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-ok\" title=\"install_lang, install_surf: ran\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (1 modules) — opam sqlite3.5.4.1\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3.mli\">sqlite3.mli</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds",
        "gate_admits_the_world": "unavailable"
      },
      "blames": {
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence",
        "gate_admits_the_world": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "built",
        "cooperation": "gated_local",
        "character": "⚠ bridge still gates, against a system this world does not use"
      },
      "placeholders": {
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "b8e9cb-python",
      "case": "sqlite-python-pip-built",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:22.357", "2026-10-06 18:35:28.471" ],
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
        "install_lang": "included",
        "install_surf": "included",
        "build_stub": "absent",
        "link_mod": "included",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "undecided",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "undecided",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided"
      },
      "badges": {
        "build_lib": "partial",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "B:d",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
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
        "pm_lang", "src_lang", "consumer_artifact"
      ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-built-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (210 names)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/python/inspect_source-fetched_lib-built-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "pip",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "_sqlite3*.so",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3/__init__.py",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "repack_preserves_api", "repack_complete",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
      "counts": { "lib_sys": "272 exports" },
      "row": {
        "sort": "sqlite|b8e9cb-python|wsl_ubuntu",
        "head": "<tr id=\"row-b8e9cb-python@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=b8e9cb-python%40wsl_ubuntu\" data-key=\"b8e9cb-python@wsl_ubuntu\"><b>sqlite</b> b8e9cb-python</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — B:d\">libsqlite3.so.0 <span class=\"rt-x\">272 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"declared_symbols_exported: holds\">✓</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:d\">libsqlite3.so.0</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art rt-off\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: n/a\">n/a</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: absent\">—</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"_sqlite3*.so\">_sqlite3*.so</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — B:d\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"dependencies_provided: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_symbols_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"soname_matches_requirement: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: included\">∈</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"pip\">pip</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-dim\" title=\"resolve_lang: absent\">—</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-dim\" title=\"depends: absent\">—</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: n/a\">n/a</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-dim\" title=\"install_lang, install_surf: included\">∈</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3/__init__.py\">sqlite3/__init__.py</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "unavailable",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "unavailable",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "unavailable",
        "signatures_agree": "n/a",
        "dependencies_provided": "unavailable",
        "gate_admits_the_world": "n/a"
      },
      "blames": {
        "required_symbols_exported": "evidence",
        "soname_matches_requirement": "evidence",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "evidence",
        "dependencies_provided": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cext",
        "lang_side": "pip",
        "native_side": "built",
        "cooperation": "no_pm",
        "character": "no package manager stands between these two artifacts"
      },
      "placeholders": {}
    },
    {
      "id": "740478-ocaml",
      "case": "sqlite-ocaml-opam-staged",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:18.762", "2026-10-06 18:35:19.651" ],
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
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds",
        "staged_interface_preserved": "holds",
        "gate_admits_the_world": "undecided"
      },
      "badges": {
        "build_lib": "partial",
        "stage": "holds",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "stage": [
          [ "staged_interface_preserved", "checked" ],
          [ "no_build_paths_in_installed_library", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "stage": [ 1, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "staged_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "bridge": { "label": "conf-sqlite3", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "surf_lang": { "label": "sqlite3.mli", "from": "declared" }
      },
      "dim": [ "pm_sys", "pkg_sys", "cap", "consumer_artifact" ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-installed-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (1 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_source-fetched_lib-installed-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libsqlite3_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_stub_source-fetched_lib-installed-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "staged_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/probe_lib_staged/inspect_source-fetched_lib-installed-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "no_build_paths_in_installed_library",
        "source_is_declared_ref", "build_tree_configured_for_source",
        "behavior_matches", "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": {
        "lib_sys": "272 exports",
        "stub_lang": "58 required",
        "staged_sys": "272 exports"
      },
      "row": {
        "sort": "sqlite|740478-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-740478-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=740478-ocaml%40wsl_ubuntu\" data-key=\"740478-ocaml@wsl_ubuntu\"><b>sqlite</b> 740478-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — I:d\">libsqlite3.so.0 <span class=\"rt-x\">272 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"declared_symbols_exported: holds\">✓</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:d\">libsqlite3.so.0</td>",
          "install_lib|p|stage": "<td class=\"rt-p rt-warm\" title=\"stage: warm\">✓</td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0\">libsqlite3.so.0 <span class=\"rt-x\">272 exports</span></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-c rt-ok\" title=\"staged_interface_preserved: holds\">✓</td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-off\"></td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libsqlite3_stubs.a\">libsqlite3_stubs.a <span class=\"rt-x\">58 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:d\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (1 modules) — opam sqlite3.5.1.0\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-sqlite3\">conf-sqlite3</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-gap\" title=\"gate_admits_the_world: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (1 modules) — opam sqlite3.5.1.0\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3.mli\">sqlite3.mli</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds",
        "staged_interface_preserved": "holds",
        "gate_admits_the_world": "unavailable"
      },
      "blames": {
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence",
        "gate_admits_the_world": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "staged",
        "cooperation": "gated_local",
        "character": "⚠ bridge still gates, against a system this world does not use"
      },
      "placeholders": {
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "740478-python",
      "case": "sqlite-python-pip-staged",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:18.762", "2026-10-06 18:35:19.674" ],
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
        "install_lang": "included",
        "install_surf": "included",
        "build_stub": "absent",
        "link_mod": "included",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "undecided",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "undecided",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "staged_interface_preserved": "holds"
      },
      "badges": {
        "build_lib": "partial",
        "stage": "holds",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "stage": [
          [ "staged_interface_preserved", "checked" ],
          [ "no_build_paths_in_installed_library", "placeholder" ]
        ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "stage": [ 1, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "I:d",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "probe_lib_staged": "observes the staged copy, which has no observation edge",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (210 names)", "from": "recorded" },
        "staged_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
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
        "src_lang", "consumer_artifact"
      ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-installed-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (210 names)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/python/inspect_source-fetched_lib-installed-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "staged_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/probe_lib_staged/inspect_source-fetched_lib-installed-dev_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "pip",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "_sqlite3*.so",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3/__init__.py",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "repack_preserves_api", "repack_complete",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
      "counts": { "lib_sys": "272 exports", "staged_sys": "272 exports" },
      "row": {
        "sort": "sqlite|740478-python|wsl_ubuntu",
        "head": "<tr id=\"row-740478-python@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=740478-python%40wsl_ubuntu\" data-key=\"740478-python@wsl_ubuntu\"><b>sqlite</b> 740478-python</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — I:d\">libsqlite3.so.0 <span class=\"rt-x\">272 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"declared_symbols_exported: holds\">✓</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:d\">libsqlite3.so.0</td>",
          "install_lib|p|stage": "<td class=\"rt-p rt-warm\" title=\"stage: warm\">✓</td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0\">libsqlite3.so.0 <span class=\"rt-x\">272 exports</span></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-c rt-ok\" title=\"staged_interface_preserved: holds\">✓</td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-off\"></td>",
          "build_binding|n|src_lang": "<td class=\"rt-art rt-off\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: n/a\">n/a</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: absent\">—</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"_sqlite3*.so\">_sqlite3*.so</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:d\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"dependencies_provided: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_symbols_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"soname_matches_requirement: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: included\">∈</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"pip\">pip</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-dim\" title=\"resolve_lang: absent\">—</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-dim\" title=\"depends: absent\">—</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: n/a\">n/a</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-dim\" title=\"install_lang, install_surf: included\">∈</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3/__init__.py\">sqlite3/__init__.py</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "unavailable",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "unavailable",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "unavailable",
        "signatures_agree": "n/a",
        "dependencies_provided": "unavailable",
        "staged_interface_preserved": "holds",
        "gate_admits_the_world": "n/a"
      },
      "blames": {
        "required_symbols_exported": "evidence",
        "soname_matches_requirement": "evidence",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "evidence",
        "dependencies_provided": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cext",
        "lang_side": "pip",
        "native_side": "staged",
        "cooperation": "no_pm",
        "character": "no package manager stands between these two artifacts"
      },
      "placeholders": {}
    },
    {
      "id": "170e8d-ocaml",
      "case": "sqlite-ocaml-opam-staged",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:28.483", "2026-10-06 18:35:29.396" ],
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
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds",
        "staged_interface_preserved": "holds",
        "gate_admits_the_world": "undecided"
      },
      "badges": {
        "build_lib": "partial",
        "stage": "holds",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "stage": [
          [ "staged_interface_preserved", "checked" ],
          [ "no_build_paths_in_installed_library", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "stage": [ 1, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "staged_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "pm_sys": { "label": "apt", "from": "declared" },
        "pkg_sys": { "label": "sqlite3", "from": "declared" },
        "hdr_sys": { "label": "sqlite3.h", "from": "declared" },
        "src_sys": { "label": "sqlite.git", "from": "declared" },
        "bridge": { "label": "conf-sqlite3", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "sqlite3", "from": "declared" },
        "surf_lang": { "label": "sqlite3.mli", "from": "declared" }
      },
      "dim": [ "pm_sys", "pkg_sys", "cap", "consumer_artifact" ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-installed-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (1 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_source-fetched_lib-installed-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libsqlite3_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_stub_source-fetched_lib-installed-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "staged_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/probe_lib_staged/inspect_source-fetched_lib-installed-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "no_build_paths_in_installed_library",
        "source_is_declared_ref", "build_tree_configured_for_source",
        "behavior_matches", "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": {
        "lib_sys": "272 exports",
        "stub_lang": "62 required",
        "staged_sys": "272 exports"
      },
      "row": {
        "sort": "sqlite|170e8d-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-170e8d-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=170e8d-ocaml%40wsl_ubuntu\" data-key=\"170e8d-ocaml@wsl_ubuntu\"><b>sqlite</b> 170e8d-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — I:d\">libsqlite3.so.0 <span class=\"rt-x\">272 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"declared_symbols_exported: holds\">✓</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:d\">libsqlite3.so.0</td>",
          "install_lib|p|stage": "<td class=\"rt-p rt-warm\" title=\"stage: warm\">✓</td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0\">libsqlite3.so.0 <span class=\"rt-x\">272 exports</span></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-c rt-ok\" title=\"staged_interface_preserved: holds\">✓</td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-off\"></td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libsqlite3_stubs.a\">libsqlite3_stubs.a <span class=\"rt-x\">62 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:d\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (1 modules) — opam sqlite3.5.4.1\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-sqlite3\">conf-sqlite3</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-gap\" title=\"gate_admits_the_world: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (1 modules) — opam sqlite3.5.4.1\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3.mli\">sqlite3.mli</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds",
        "staged_interface_preserved": "holds",
        "gate_admits_the_world": "unavailable"
      },
      "blames": {
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence",
        "gate_admits_the_world": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "staged",
        "cooperation": "gated_local",
        "character": "⚠ bridge still gates, against a system this world does not use"
      },
      "placeholders": {
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "170e8d-python",
      "case": "sqlite-python-pip-staged",
      "project": "sqlite",
      "scenario": "source-fetched_lib-installed-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:28.483", "2026-10-06 18:35:29.420" ],
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
        "install_lang": "included",
        "install_surf": "included",
        "build_stub": "absent",
        "link_mod": "included",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "undecided",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "undecided",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided",
        "staged_interface_preserved": "holds"
      },
      "badges": {
        "build_lib": "partial",
        "stage": "holds",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "stage": [
          [ "staged_interface_preserved", "checked" ],
          [ "no_build_paths_in_installed_library", "placeholder" ]
        ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "stage": [ 1, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "I:d",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {
        "fetch_source": "no edge for this action on the page",
        "probe_lib_staged": "observes the staged copy, which has no observation edge",
        "probe_lib_apt": "observes the system package's library, which this world does not use"
      },
      "names": {
        "lib_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
        "mod_lang": { "label": "sqlite3 (210 names)", "from": "recorded" },
        "staged_sys": { "label": "libsqlite3.so.0", "from": "recorded" },
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
        "src_lang", "consumer_artifact"
      ],
      "lines": {
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/build_lib/inspect_source-fetched_lib-installed-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "sqlite3 (210 names)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/python/inspect_source-fetched_lib-installed-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "staged_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/probe_lib_staged/inspect_source-fetched_lib-installed-dev_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "pip",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "_sqlite3*.so",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3/__init__.py",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "repack_preserves_api", "repack_complete",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
      "counts": { "lib_sys": "272 exports", "staged_sys": "272 exports" },
      "row": {
        "sort": "sqlite|170e8d-python|wsl_ubuntu",
        "head": "<tr id=\"row-170e8d-python@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=170e8d-python%40wsl_ubuntu\" data-key=\"170e8d-python@wsl_ubuntu\"><b>sqlite</b> 170e8d-python</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite.git — F\">sqlite.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — I:d\">libsqlite3.so.0 <span class=\"rt-x\">272 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"declared_symbols_exported: holds\">✓</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:d\">libsqlite3.so.0</td>",
          "install_lib|p|stage": "<td class=\"rt-p rt-warm\" title=\"stage: warm\">✓</td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0\">libsqlite3.so.0 <span class=\"rt-x\">272 exports</span></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-c rt-ok\" title=\"staged_interface_preserved: holds\">✓</td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-off\"></td>",
          "build_binding|n|src_lang": "<td class=\"rt-art rt-off\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: n/a\">n/a</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: absent\">—</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"_sqlite3*.so\">_sqlite3*.so</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — I:d\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"dependencies_provided: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_symbols_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"soname_matches_requirement: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: included\">∈</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"pip\">pip</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-dim\" title=\"resolve_lang: absent\">—</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-dim\" title=\"depends: absent\">—</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: n/a\">n/a</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-dim\" title=\"install_lang, install_surf: included\">∈</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3/__init__.py\">sqlite3/__init__.py</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "unavailable",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "unavailable",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "unavailable",
        "signatures_agree": "n/a",
        "dependencies_provided": "unavailable",
        "staged_interface_preserved": "holds",
        "gate_admits_the_world": "n/a"
      },
      "blames": {
        "required_symbols_exported": "evidence",
        "soname_matches_requirement": "evidence",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "evidence",
        "dependencies_provided": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cext",
        "lang_side": "pip",
        "native_side": "staged",
        "cooperation": "no_pm",
        "character": "no package manager stands between these two artifacts"
      },
      "placeholders": {}
    },
    {
      "id": "c2ff32-ocaml",
      "case": "sqlite-ocaml-opam-apt",
      "project": "sqlite",
      "scenario": "source-fetched_lib-fetched_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:20.607", "2026-10-06 18:35:21.386" ],
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
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds",
        "gate_admits_the_world": "undecided"
      },
      "badges": {
        "realize_sys": "partial",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "lines": {
        "mod_lang": {
          "text": "sqlite3 (1 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_source-fetched_lib-fetched_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libsqlite3_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_stub_source-fetched_lib-fetched_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/probe_lib/inspect_source-fetched_lib-fetched_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "render",
          "what": "the package is declared, but its installed VERSION is asked of the machine rendering this page — the run never recorded it (status.md §2.7 finding 2)",
          "at": "Canary_matrix.fetched_note → sys_pkg_version"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": { "stub_lang": "58 required", "lib_sys": "1422 exports" },
      "row": {
        "sort": "sqlite|c2ff32-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-c2ff32-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=c2ff32-ocaml%40wsl_ubuntu\" data-key=\"c2ff32-ocaml@wsl_ubuntu\"><b>sqlite</b> c2ff32-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_sys: warm\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-warm\" title=\"realize_sys, realize_hdr: warm\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — apt sqlite3.3.45.1\">libsqlite3.so.0 <span class=\"rt-x\">1422 exports</span></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-ok\" title=\"declared_symbols_exported: holds\">✓</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — apt sqlite3.3.45.1\">libsqlite3.so.0</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libsqlite3_stubs.a\">libsqlite3_stubs.a <span class=\"rt-x\">58 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — apt sqlite3.3.45.1\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (1 modules) — opam sqlite3.5.1.0\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-sqlite3\">conf-sqlite3</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-gap\" title=\"gate_admits_the_world: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (1 modules) — opam sqlite3.5.1.0\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3.mli\">sqlite3.mli</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds",
        "gate_admits_the_world": "unavailable"
      },
      "blames": {
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence",
        "gate_admits_the_world": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "apt",
        "cooperation": "conf",
        "character": "symbolic package bridge + artifact validation"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ],
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "c2ff32-python",
      "case": "sqlite-python-pip-apt",
      "project": "sqlite",
      "scenario": "source-fetched_lib-fetched_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:20.607", "2026-10-06 18:35:21.410" ],
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
        "install_lang": "included",
        "install_surf": "included",
        "build_stub": "absent",
        "link_mod": "included",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "undecided",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "undecided",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided"
      },
      "badges": {
        "realize_sys": "partial",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "apt sqlite3.3.45.1",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {},
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
        "consumer_artifact"
      ],
      "lines": {
        "mod_lang": {
          "text": "sqlite3 (210 names)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/python/inspect_source-fetched_lib-fetched_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/probe_lib/inspect_source-fetched_lib-fetched_ocaml_binding-fetched-5.1.0_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "pip",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "_sqlite3*.so",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3/__init__.py",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "render",
          "what": "the package is declared, but its installed VERSION is asked of the machine rendering this page — the run never recorded it (status.md §2.7 finding 2)",
          "at": "Canary_matrix.fetched_note → sys_pkg_version"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "src_sys", "staged_sys", "cap", "bridge", "src_lang", "realize_cap",
        "build_lib", "build_hdr", "stage", "depext", "depends", "conf_probe",
        "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "repack_preserves_api", "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
      "counts": { "lib_sys": "1422 exports" },
      "row": {
        "sort": "sqlite|c2ff32-python|wsl_ubuntu",
        "head": "<tr id=\"row-c2ff32-python@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=c2ff32-python%40wsl_ubuntu\" data-key=\"c2ff32-python@wsl_ubuntu\"><b>sqlite</b> c2ff32-python</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_sys: warm\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-warm\" title=\"realize_sys, realize_hdr: warm\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — apt sqlite3.3.45.1\">libsqlite3.so.0 <span class=\"rt-x\">1422 exports</span></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-ok\" title=\"declared_symbols_exported: holds\">✓</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — apt sqlite3.3.45.1\">libsqlite3.so.0</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art rt-off\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: n/a\">n/a</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: absent\">—</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"_sqlite3*.so\">_sqlite3*.so</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — apt sqlite3.3.45.1\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"dependencies_provided: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_symbols_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"soname_matches_requirement: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: included\">∈</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"pip\">pip</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-dim\" title=\"resolve_lang: absent\">—</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-dim\" title=\"depends: absent\">—</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: n/a\">n/a</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-dim\" title=\"install_lang, install_surf: included\">∈</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3/__init__.py\">sqlite3/__init__.py</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "unavailable",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "unavailable",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "unavailable",
        "signatures_agree": "n/a",
        "dependencies_provided": "unavailable",
        "gate_admits_the_world": "n/a"
      },
      "blames": {
        "required_symbols_exported": "evidence",
        "soname_matches_requirement": "evidence",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "evidence",
        "dependencies_provided": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cext",
        "lang_side": "pip",
        "native_side": "apt",
        "cooperation": "no_pm",
        "character": "no package manager stands between these two artifacts"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ]
      }
    },
    {
      "id": "4af838-ocaml",
      "case": "sqlite-ocaml-opam-apt",
      "project": "sqlite",
      "scenario": "source-fetched_lib-fetched_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:30.388", "2026-10-06 18:35:31.155" ],
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
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds",
        "gate_admits_the_world": "undecided"
      },
      "badges": {
        "realize_sys": "partial",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "lines": {
        "mod_lang": {
          "text": "sqlite3 (1 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_source-fetched_lib-fetched_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libsqlite3_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/ocaml/inspect_stub_source-fetched_lib-fetched_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/probe_lib/inspect_source-fetched_lib-fetched_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "render",
          "what": "the package is declared, but its installed VERSION is asked of the machine rendering this page — the run never recorded it (status.md §2.7 finding 2)",
          "at": "Canary_matrix.fetched_note → sys_pkg_version"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": { "stub_lang": "62 required", "lib_sys": "1422 exports" },
      "row": {
        "sort": "sqlite|4af838-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-4af838-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=4af838-ocaml%40wsl_ubuntu\" data-key=\"4af838-ocaml@wsl_ubuntu\"><b>sqlite</b> 4af838-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_sys: warm\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-warm\" title=\"realize_sys, realize_hdr: warm\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — apt sqlite3.3.45.1\">libsqlite3.so.0 <span class=\"rt-x\">1422 exports</span></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-ok\" title=\"declared_symbols_exported: holds\">✓</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — apt sqlite3.3.45.1\">libsqlite3.so.0</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libsqlite3_stubs.a\">libsqlite3_stubs.a <span class=\"rt-x\">62 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — apt sqlite3.3.45.1\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (1 modules) — opam sqlite3.5.4.1\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-sqlite3\">conf-sqlite3</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-gap\" title=\"gate_admits_the_world: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (1 modules) — opam sqlite3.5.4.1\">sqlite3 (1 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3.mli\">sqlite3.mli</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds",
        "gate_admits_the_world": "unavailable"
      },
      "blames": {
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence",
        "gate_admits_the_world": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "apt",
        "cooperation": "conf",
        "character": "symbolic package bridge + artifact validation"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ],
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "4af838-python",
      "case": "sqlite-python-pip-apt",
      "project": "sqlite",
      "scenario": "source-fetched_lib-fetched_ocaml_binding-fetched-5.4.1_python_binding-fetched",
      "lang": "python",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-10-06 18:35:30.388", "2026-10-06 18:35:31.178" ],
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
        "install_lang": "included",
        "install_surf": "included",
        "build_stub": "absent",
        "link_mod": "included",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "undecided",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "undecided",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "dependencies_provided": "undecided"
      },
      "badges": {
        "realize_sys": "partial",
        "install_surf": "holds",
        "link_mod": "undecided"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
      },
      "nodes": {
        "src_sys": "F",
        "lib_sys": "apt sqlite3.3.45.1",
        "mod_lang": "pip sqlite3"
      },
      "unplaced": {},
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
        "consumer_artifact"
      ],
      "lines": {
        "mod_lang": {
          "text": "sqlite3 (210 names)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/fetch_binding/python/inspect_source-fetched_lib-fetched_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "lib_sys": {
          "text": "libsqlite3.so.0",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/sqlite/probe_lib/inspect_source-fetched_lib-fetched_ocaml_binding-fetched-5.4.1_python_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "sqlite3.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "sqlite.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "pip",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "sqlite3",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "_sqlite3*.so",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "sqlite3/__init__.py",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "render",
          "what": "the package is declared, but its installed VERSION is asked of the machine rendering this page — the run never recorded it (status.md §2.7 finding 2)",
          "at": "Canary_matrix.fetched_note → sys_pkg_version"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "src_sys", "staged_sys", "cap", "bridge", "src_lang", "realize_cap",
        "build_lib", "build_hdr", "stage", "depext", "depends", "conf_probe",
        "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "repack_preserves_api", "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
      "counts": { "lib_sys": "1422 exports" },
      "row": {
        "sort": "sqlite|4af838-python|wsl_ubuntu",
        "head": "<tr id=\"row-4af838-python@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=4af838-python%40wsl_ubuntu\" data-key=\"4af838-python@wsl_ubuntu\"><b>sqlite</b> 4af838-python</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_sys: warm\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-warm\" title=\"realize_sys, realize_hdr: warm\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libsqlite3.so.0 — apt sqlite3.3.45.1\">libsqlite3.so.0 <span class=\"rt-x\">1422 exports</span></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"sqlite3.h\">sqlite3.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-ok\" title=\"declared_symbols_exported: holds\">✓</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — apt sqlite3.3.45.1\">libsqlite3.so.0</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art rt-off\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"sqlite3.h\">sqlite3.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: n/a\">n/a</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: absent\">—</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"_sqlite3*.so\">_sqlite3*.so</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libsqlite3.so.0 — apt sqlite3.3.45.1\">libsqlite3.so.0</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"dependencies_provided: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_symbols_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"soname_matches_requirement: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: included\">∈</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"pip\">pip</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-dim\" title=\"resolve_lang: absent\">—</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"sqlite3\">sqlite3</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-dim\" title=\"depends: absent\">—</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: n/a\">n/a</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-dim\" title=\"install_lang, install_surf: included\">∈</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"sqlite3 (210 names) — pip sqlite3\">sqlite3 (210 names)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"sqlite3/__init__.py\">sqlite3/__init__.py</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"sqlite3\">sqlite3</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "unavailable",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "unavailable",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "unavailable",
        "signatures_agree": "n/a",
        "dependencies_provided": "unavailable",
        "gate_admits_the_world": "n/a"
      },
      "blames": {
        "required_symbols_exported": "evidence",
        "soname_matches_requirement": "evidence",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "evidence",
        "dependencies_provided": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cext",
        "lang_side": "pip",
        "native_side": "apt",
        "cooperation": "no_pm",
        "character": "no package manager stands between these two artifacts"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ]
      }
    },
    {
      "id": "d26e75-ocaml",
      "case": "llvm-ocaml-opam-apt",
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
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "xfail",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "unevaluated",
        "required_symbols_exported": "unevaluated",
        "api_names_present": "unevaluated",
        "soname_matches_declaration": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_versions_exported": "unevaluated",
        "signatures_agree": "unevaluated",
        "dependencies_provided": "unevaluated"
      },
      "badges": {
        "realize_sys": "unevaluated",
        "install_surf": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "lines": {
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "llvm-19-dev",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "lib_sys": {
          "text": "libLLVM.so",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.soname",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "Core.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "llvm-project.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-llvm-shared {= 19}",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "llvm",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "libllvm.a",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "llvm.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": {},
      "row": {
        "sort": "llvm|d26e75-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-d26e75-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=d26e75-ocaml%40wsl_ubuntu\" data-key=\"d26e75-ocaml@wsl_ubuntu\"><b>llvm</b> d26e75-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-ok\" title=\"resolve_sys: ran\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"llvm-19-dev\">llvm-19-dev</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-ok\" title=\"realize_sys, realize_hdr: ran\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-decl\" title=\"libLLVM.so — apt llvm-19-dev.19\">libLLVM.so</td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"Core.h\">Core.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_symbols_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_versions_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"soname_matches_declaration: not evaluated in any recorded run\">·</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libLLVM.so — apt llvm-19-dev.19\">libLLVM.so</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"Core.h\">Core.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: not evaluated in any recorded run\">·</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"libllvm.a\">libllvm.a</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libLLVM.so — apt llvm-19-dev.19\">libLLVM.so</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"dependencies_provided: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_symbols_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_versions_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"soname_matches_requirement: not evaluated in any recorded run\">·</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"opam llvm.19-shared\">opam llvm.19-shared</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-ok\" title=\"resolve_lang: ran\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"llvm\">llvm</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-ok\" title=\"depends: ran\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-llvm-shared {= 19}\">conf-llvm-shared {= 19}</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: not evaluated in any recorded run\">·</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-ok\" title=\"install_lang, install_surf: ran\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"opam llvm.19-shared\"></td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"llvm.mli\">llvm.mli</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-dim\" title=\"api_names_present: not evaluated in any recorded run\">·</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"llvm\">llvm</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-xf\" title=\"run_packaged: xfail\">xf</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {},
      "blames": {},
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "apt",
        "cooperation": "conf",
        "character": "symbolic package bridge + artifact validation"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ],
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "c8fae6-ocaml",
      "case": "llvm-ocaml-built-built",
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
        "required_symbols_exported": "unevaluated",
        "soname_matches_declaration": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_versions_exported": "unevaluated",
        "signatures_agree": "unevaluated",
        "dependencies_provided": "unevaluated",
        "staged_interface_preserved": "unevaluated"
      },
      "badges": {
        "build_lib": "unevaluated",
        "stage": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "stage": [
          [ "staged_interface_preserved", "checked" ],
          [ "no_build_paths_in_installed_library", "placeholder" ]
        ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run": [
          [ "behavior_matches", "placeholder" ],
          [ "correspondence_holds_across_the_binding", "placeholder" ],
          [ "no_duplicate_implementation", "placeholder" ],
          [ "interposition_binds_build_target", "placeholder" ],
          [ "denotation_stable_across_worlds", "placeholder" ]
        ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "stage": [ 1, 1 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run": [ 0, 5 ]
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
        "pm_lang": { "label": "opam", "from": "declared" },
        "stub_lang": { "label": "libllvm.a", "from": "declared" },
        "surf_lang": { "label": "llvm.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "cap", "bridge", "pm_lang", "pkg_lang",
        "surf_lang", "consumer_package"
      ],
      "lines": {
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "llvm-19-dev",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "lib_sys": {
          "text": "libLLVM.so",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.soname",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "Core.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "llvm-project.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "libllvm.a",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "llvm.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "pm_lang", "pkg_lang",
        "consumer_package", "resolve_sys", "realize_sys", "realize_hdr",
        "realize_cap", "depext", "depends", "conf_probe", "discover",
        "resolve_lang", "install_lang", "install_surf", "pack",
        "run_packaged", "same_program"
      ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "compatibility_version_satisfied"
      ],
      "counts": {},
      "row": {
        "sort": "llvm|c8fae6-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-c8fae6-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=c8fae6-ocaml%40wsl_ubuntu\" data-key=\"c8fae6-ocaml@wsl_ubuntu\"><b>llvm</b> c8fae6-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"llvm-project.git — F latest\">llvm-project.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-dim\" title=\"build_lib: unrecorded\">·</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-decl\" title=\"libLLVM.so — B:d\">libLLVM.so</td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-dim\" title=\"declared_symbols_exported: not evaluated in any recorded run\">·</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-dim\" title=\"declared_versions_exported: not evaluated in any recorded run\">·</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-dim\" title=\"soname_matches_declaration: not evaluated in any recorded run\">·</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-rep\" title=\"llvm-project.git — F latest\">llvm-project.git</td>",
          "build_headers|p|build_hdr": "<td class=\"rt-p rt-dim\" title=\"build_hdr: unrecorded\">·</td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"Core.h\">Core.h</td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libLLVM.so — B:d\">libLLVM.so</td>",
          "install_lib|p|stage": "<td class=\"rt-p rt-dim\" title=\"stage: unrecorded\">·</td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art\" title=\"\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-c rt-dim\" title=\"staged_interface_preserved: not evaluated in any recorded run\">·</td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libLLVM.so — B:d\">libLLVM.so</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-dim\" title=\"probe_lib: unrecorded\">·</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"Core.h\">Core.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: not evaluated in any recorded run\">·</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: unrecorded\">·</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"libllvm.a\">libllvm.a</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libLLVM.so — B:d\">libLLVM.so</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"dependencies_provided: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_symbols_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_versions_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"soname_matches_requirement: not evaluated in any recorded run\">·</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: unrecorded\">·</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"B:d\">B:d</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_binding|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|depends": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-off\"></td>",
          "fetch_binding|p|install": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-off\"></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-off\"></td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"B:d\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libLLVM.so — B:d\">libLLVM.so</td>",
          "probe_binding · run|p|run": "<td class=\"rt-p rt-dim\" title=\"run: unrecorded\">·</td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog\" title=\"\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-off\"></td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog rt-off\"></td>"
        }
      },
      "outcomes": {},
      "blames": {},
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "built",
        "native_side": "built",
        "cooperation": "local",
        "character": "no provider ecosystem — the native side is local"
      },
      "placeholders": {}
    },
    {
      "id": "9f4072-ocaml",
      "case": "llvm-ocaml-built-built",
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
        "required_symbols_exported": "unevaluated",
        "soname_matches_declaration": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_versions_exported": "unevaluated",
        "signatures_agree": "unevaluated",
        "dependencies_provided": "unevaluated",
        "staged_interface_preserved": "unevaluated"
      },
      "badges": {
        "build_lib": "unevaluated",
        "stage": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "stage": [
          [ "staged_interface_preserved", "checked" ],
          [ "no_build_paths_in_installed_library", "placeholder" ]
        ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run": [
          [ "behavior_matches", "placeholder" ],
          [ "correspondence_holds_across_the_binding", "placeholder" ],
          [ "no_duplicate_implementation", "placeholder" ],
          [ "interposition_binds_build_target", "placeholder" ],
          [ "denotation_stable_across_worlds", "placeholder" ]
        ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "stage": [ 1, 1 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run": [ 0, 5 ]
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
        "pm_lang": { "label": "opam", "from": "declared" },
        "stub_lang": { "label": "libllvm.a", "from": "declared" },
        "surf_lang": { "label": "llvm.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "cap", "bridge", "pm_lang", "pkg_lang",
        "surf_lang", "consumer_package"
      ],
      "lines": {
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "llvm-19-dev",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "lib_sys": {
          "text": "libLLVM.so",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.soname",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "Core.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "llvm-project.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "libllvm.a",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "llvm.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "pm_lang", "pkg_lang",
        "consumer_package", "resolve_sys", "realize_sys", "realize_hdr",
        "realize_cap", "depext", "depends", "conf_probe", "discover",
        "resolve_lang", "install_lang", "install_surf", "pack",
        "run_packaged", "same_program"
      ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "compatibility_version_satisfied"
      ],
      "counts": {},
      "row": {
        "sort": "llvm|9f4072-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-9f4072-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=9f4072-ocaml%40wsl_ubuntu\" data-key=\"9f4072-ocaml@wsl_ubuntu\"><b>llvm</b> 9f4072-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-decl\" title=\"llvm-project.git — F arbipher\">llvm-project.git</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-ok\" title=\"build_lib: ran\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-decl\" title=\"libLLVM.so — B:d\">libLLVM.so</td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-dim\" title=\"declared_symbols_exported: not evaluated in any recorded run\">·</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-dim\" title=\"declared_versions_exported: not evaluated in any recorded run\">·</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-dim\" title=\"soname_matches_declaration: not evaluated in any recorded run\">·</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-rep\" title=\"llvm-project.git — F arbipher\">llvm-project.git</td>",
          "build_headers|p|build_hdr": "<td class=\"rt-p rt-ok\" title=\"build_hdr: ran\">✓</td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"Core.h\">Core.h</td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libLLVM.so — B:d\">libLLVM.so</td>",
          "install_lib|p|stage": "<td class=\"rt-p rt-ok\" title=\"stage: ran\">✓</td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art\" title=\"\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-c rt-dim\" title=\"staged_interface_preserved: not evaluated in any recorded run\">·</td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libLLVM.so — B:d\">libLLVM.so</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"Core.h\">Core.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: not evaluated in any recorded run\">·</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-ok\" title=\"build_stub: ran\">✓</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"libllvm.a\">libllvm.a</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libLLVM.so — B:d\">libLLVM.so</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"dependencies_provided: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_symbols_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_versions_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"soname_matches_requirement: not evaluated in any recorded run\">·</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-ok\" title=\"link_mod: ran\">✓</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"B:d\">B:d</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_binding|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|depends": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-off\"></td>",
          "fetch_binding|p|install": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-off\"></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-off\"></td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"B:d\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libLLVM.so — B:d\">libLLVM.so</td>",
          "probe_binding · run|p|run": "<td class=\"rt-p rt-ok\" title=\"run: ran\">✓</td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog\" title=\"\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-off\"></td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog rt-off\"></td>"
        }
      },
      "outcomes": {},
      "blames": {},
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "built",
        "native_side": "built",
        "cooperation": "local",
        "character": "no provider ecosystem — the native side is local"
      },
      "placeholders": {}
    },
    {
      "id": "28a379-ocaml",
      "case": "tiny-full-ocaml-vendored-vendored",
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
        "required_symbols_exported": "unevaluated",
        "soname_matches_declaration": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_versions_exported": "unevaluated",
        "signatures_agree": "unevaluated",
        "dependencies_provided": "unevaluated"
      },
      "badges": {
        "build_lib": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run": [
          [ "behavior_matches", "placeholder" ],
          [ "correspondence_holds_across_the_binding", "placeholder" ],
          [ "no_duplicate_implementation", "placeholder" ],
          [ "interposition_binds_build_target", "placeholder" ],
          [ "denotation_stable_across_worlds", "placeholder" ]
        ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run": [ 0, 5 ]
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
      "lines": {
        "lib_sys": {
          "text": "libtiny.so.1",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/tiny-full/build_lib/inspect_source-vendored-stable_lib-vendored-stable_ocaml_binding-vendored-stable_python_binding-vendored-stable_python_binding-vendored-stable_app-vendored-stable_app-vendored-stable.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libtiny_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/tiny-full/build_binding/ocaml/inspect_source-vendored-stable_lib-vendored-stable_ocaml_binding-vendored-stable_python_binding-vendored-stable_python_binding-vendored-stable_app-vendored-stable_app-vendored-stable.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "hdr_sys": {
          "text": "tiny.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "tiny.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "pm_sys", "pkg_sys", "staged_sys", "cap", "bridge", "pm_lang",
        "pkg_lang", "consumer_package", "resolve_sys", "realize_sys",
        "realize_hdr", "realize_cap", "stage", "depext", "depends",
        "conf_probe", "discover", "resolve_lang", "install_lang",
        "install_surf", "pack", "run_packaged", "same_program"
      ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "source_is_declared_ref", "build_tree_configured_for_source",
        "behavior_matches", "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "compatibility_version_satisfied"
      ],
      "counts": {
        "lib_sys": "3 exports",
        "stub_lang": "3 required",
        "surf_lang": "1 modules"
      },
      "row": {
        "sort": "tiny-full|28a379-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-28a379-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=28a379-ocaml%40wsl_ubuntu\" data-key=\"28a379-ocaml@wsl_ubuntu\"><b>tiny-full</b> 28a379-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art\" title=\"V:s\">V:s</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-warm\" title=\"build_lib: warm\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libtiny.so.1 — V:s\">libtiny.so.1 <span class=\"rt-x\">3 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-dim\" title=\"declared_symbols_exported: not evaluated in any recorded run\">·</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-dim\" title=\"declared_versions_exported: not evaluated in any recorded run\">·</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-dim\" title=\"soname_matches_declaration: not evaluated in any recorded run\">·</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libtiny.so.1 — V:s\">libtiny.so.1</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-warm\" title=\"probe_lib: warm\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"tiny.h\">tiny.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: not evaluated in any recorded run\">·</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-warm\" title=\"build_stub: warm\">✓</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libtiny_stubs.a\">libtiny_stubs.a <span class=\"rt-x\">3 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libtiny.so.1 — V:s\">libtiny.so.1</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"dependencies_provided: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_symbols_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_versions_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"soname_matches_requirement: not evaluated in any recorded run\">·</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-warm\" title=\"link_mod: warm\">✓</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"V:s\">V:s</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_binding|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|depends": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-off\"></td>",
          "fetch_binding|p|install": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-off\"></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-off\"></td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"V:s\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libtiny.so.1 — V:s\">libtiny.so.1</td>",
          "probe_binding · run|p|run": "<td class=\"rt-p rt-warm\" title=\"run: warm\">✓</td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog\" title=\"\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-off\"></td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog rt-off\"></td>"
        }
      },
      "outcomes": {},
      "blames": {},
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "vendored",
        "native_side": "vendored",
        "cooperation": "local",
        "character": "no provider ecosystem — the native side is local"
      },
      "placeholders": {}
    },
    {
      "id": "28a379-python",
      "case": "tiny-full-python-vendored-vendored",
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
        "required_symbols_exported": "unevaluated",
        "soname_matches_declaration": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_versions_exported": "unevaluated",
        "dependencies_provided": "unevaluated"
      },
      "badges": { "build_lib": "unevaluated", "link_mod": "unevaluated" },
      "edge_claims": {
        "build_lib": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ],
          [ "source_is_declared_ref", "placeholder" ],
          [ "build_tree_configured_for_source", "placeholder" ]
        ],
        "build_stub": [ [ "signatures_match_debug_info", "placeholder" ] ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run": [
          [ "behavior_matches", "placeholder" ],
          [ "correspondence_holds_across_the_binding", "placeholder" ],
          [ "no_duplicate_implementation", "placeholder" ],
          [ "interposition_binds_build_target", "placeholder" ],
          [ "denotation_stable_across_worlds", "placeholder" ]
        ]
      },
      "edge_counts": {
        "build_lib": [ 3, 3 ],
        "build_stub": [ 0, 1 ],
        "link_mod": [ 4, 1 ],
        "run": [ 0, 5 ]
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
      "lines": {
        "lib_sys": {
          "text": "libtiny.so.1",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/tiny-full/build_lib/inspect_source-vendored-stable_lib-vendored-stable_ocaml_binding-vendored-stable_python_binding-vendored-stable_python_binding-vendored-stable_app-vendored-stable_app-vendored-stable.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "_native.cpython-314-x86_64-linux-gnu.so",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/tiny-full/build_binding/python/inspect_source-vendored-stable_lib-vendored-stable_ocaml_binding-vendored-stable_python_binding-vendored-stable_python_binding-vendored-stable_app-vendored-stable_app-vendored-stable.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "mod_lang": {
          "text": "tiny_cext (3 names)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/tiny-full/probe_binding/python/inspect_source-vendored-stable_lib-vendored-stable_ocaml_binding-vendored-stable_python_binding-vendored-stable_python_binding-vendored-stable_app-vendored-stable_app-vendored-stable.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "hdr_sys": {
          "text": "tiny.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "tiny_cext/__init__.py",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "pm_sys", "pkg_sys", "staged_sys", "cap", "bridge", "pm_lang",
        "pkg_lang", "consumer_package", "resolve_sys", "realize_sys",
        "realize_hdr", "realize_cap", "stage", "depext", "depends",
        "conf_probe", "discover", "resolve_lang", "install_lang",
        "install_surf", "pack", "run_packaged", "same_program"
      ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "source_is_declared_ref", "build_tree_configured_for_source",
        "behavior_matches", "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "compatibility_version_satisfied"
      ],
      "counts": { "lib_sys": "3 exports", "stub_lang": "3 required" },
      "row": {
        "sort": "tiny-full|28a379-python|wsl_ubuntu",
        "head": "<tr id=\"row-28a379-python@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=28a379-python%40wsl_ubuntu\" data-key=\"28a379-python@wsl_ubuntu\"><b>tiny-full</b> 28a379-python</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art\" title=\"V:s\">V:s</td>",
          "build_lib|p|build_lib": "<td class=\"rt-p rt-warm\" title=\"build_lib: warm\">✓</td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libtiny.so.1 — V:s\">libtiny.so.1 <span class=\"rt-x\">3 exports</span></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-c rt-dim\" title=\"declared_symbols_exported: not evaluated in any recorded run\">·</td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-c rt-dim\" title=\"declared_versions_exported: not evaluated in any recorded run\">·</td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-c rt-dim\" title=\"soname_matches_declaration: not evaluated in any recorded run\">·</td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libtiny.so.1 — V:s\">libtiny.so.1</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-warm\" title=\"probe_lib: warm\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"tiny.h\">tiny.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: n/a\">n/a</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-warm\" title=\"build_stub: warm\">✓</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"_native.cpython-314-x86_64-linux-gnu.so\">_native.cpython-314-x86_64-linux-gnu.so <span class=\"rt-x\">3 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libtiny.so.1 — V:s\">libtiny.so.1</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"dependencies_provided: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_symbols_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_versions_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"soname_matches_requirement: not evaluated in any recorded run\">·</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-warm\" title=\"link_mod: warm\">✓</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"tiny_cext (3 names) — V:s\">tiny_cext (3 names)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_binding|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|depends": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-off\"></td>",
          "fetch_binding|p|install": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-off\"></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-off\"></td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"tiny_cext (3 names) — V:s\">tiny_cext (3 names)</td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libtiny.so.1 — V:s\">libtiny.so.1</td>",
          "probe_binding · run|p|run": "<td class=\"rt-p rt-warm\" title=\"run: warm\">✓</td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog\" title=\"\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-off\"></td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog rt-off\"></td>"
        }
      },
      "outcomes": {
        "signatures_agree": "n/a",
        "gate_admits_the_world": "n/a"
      },
      "blames": {},
      "observed": {},
      "chain": {
        "mechanism": "cext",
        "lang_side": "vendored",
        "native_side": "vendored",
        "cooperation": "local",
        "character": "no provider ecosystem — the native side is local"
      },
      "placeholders": {}
    },
    {
      "id": "614dda-ocaml",
      "case": "zarith-ocaml-built-apt",
      "project": "zarith",
      "scenario": "lib-fetched_ocaml_binding-built-dev_binding_source_ocaml-fetched-master",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-28 15:51:01.789", "2026-09-28 15:51:11.965" ],
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
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "undecided",
        "soname_matches_requirement": "undecided",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "undecided"
      },
      "badges": {
        "realize_sys": "partial",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "pack": [
          [ "repack_preserves_api", "placeholder" ],
          [ "repack_complete", "placeholder" ]
        ],
        "run": [
          [ "behavior_matches", "placeholder" ],
          [ "correspondence_holds_across_the_binding", "placeholder" ],
          [ "no_duplicate_implementation", "placeholder" ],
          [ "interposition_binds_build_target", "placeholder" ],
          [ "denotation_stable_across_worlds", "placeholder" ]
        ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "discover": [ 0, 1 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "pack": [ 0, 2 ],
        "run": [ 0, 5 ],
        "same_program": [ 0, 1 ]
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
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "zarith-no-conf", "from": "declared" },
        "src_lang": { "label": "Zarith.git", "from": "declared" },
        "surf_lang": { "label": "zarith.mli", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "bridge", "pm_lang", "surf_lang",
        "consumer_package"
      ],
      "lines": {
        "mod_lang": {
          "text": "zarith (4 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/zarith/build_binding/ocaml/inspect_lib-fetched_ocaml_binding-built-dev_binding_source_ocaml-fetched-master.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libzarith.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/zarith/pack_binding/ocaml/inspect_stub_lib-fetched_ocaml_binding-built-dev_binding_source_ocaml-fetched-master.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "lib_sys": {
          "text": "libgmp.so.10",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/zarith/probe_lib/inspect_lib-fetched_ocaml_binding-built-dev_binding_source_ocaml-fetched-master.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "libgmp-dev",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "gmp.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "zarith-no-conf",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the wrapper package this world publishes (pr_wrapper_pkgs)",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_lang": {
          "text": "Zarith.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "zarith.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "lib_sys": {
          "kind": "render",
          "what": "the package is declared, but its installed VERSION is asked of the machine rendering this page — the run never recorded it (status.md §2.7 finding 2)",
          "at": "Canary_matrix.fetched_note → sys_pkg_version"
        },
        "src_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "src_sys", "staged_sys", "bridge", "build_lib", "build_hdr", "stage",
        "depext", "depends", "conf_probe"
      ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link"
      ],
      "counts": {
        "surf_lang": "4 modules",
        "stub_lang": "23 required",
        "lib_sys": "620 exports"
      },
      "row": {
        "sort": "zarith|614dda-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-614dda-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=614dda-ocaml%40wsl_ubuntu\" data-key=\"614dda-ocaml@wsl_ubuntu\"><b>zarith</b> 614dda-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_sys: warm\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"libgmp-dev\">libgmp-dev</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-warm\" title=\"realize_sys, realize_hdr: warm\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libgmp.so.10 — apt libgmp-dev.2:6.3.0+dfsg\">libgmp.so.10 <span class=\"rt-x\">620 exports</span></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"gmp.h\">gmp.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-ok\" title=\"declared_symbols_exported: holds\">✓</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-gap\" title=\"soname_matches_declaration: undeclared — blame: declaration (read, but the project declared nothing to compare)\">no-decl</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libgmp.so.10 — apt libgmp-dev.2:6.3.0+dfsg\">libgmp.so.10</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-warm\" title=\"probe_lib: warm\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art rt-decl\" title=\"Zarith.git — F master\">Zarith.git</td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"gmp.h\">gmp.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-warm\" title=\"build_stub: warm\">✓</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libzarith.a\">libzarith.a <span class=\"rt-x\">23 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libgmp.so.10 — apt libgmp-dev.2:6.3.0+dfsg\">libgmp.so.10</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"dependencies_provided: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"soname_matches_requirement: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-warm\" title=\"link_mod: warm\">✓</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"zarith (4 modules) — B:d\">zarith (4 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_binding|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|depends": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-off\"></td>",
          "fetch_binding|p|install": "<td class=\"rt-off\"></td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-off\"></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-off\"></td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"zarith (4 modules) — B:d\">zarith (4 modules)</td>",
          "pack_binding|p|pack": "<td class=\"rt-p rt-ok\" title=\"pack: ran\">✓</td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"zarith-no-conf\">zarith-no-conf</td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"zarith (4 modules) — B:d\">zarith (4 modules)</td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libgmp.so.10 — apt libgmp-dev.2:6.3.0+dfsg\">libgmp.so.10</td>",
          "probe_binding · run|p|run": "<td class=\"rt-p rt-warm\" title=\"run: warm\">✓</td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog\" title=\"\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-off\"></td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog rt-off\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "undeclared",
        "soname_matches_requirement": "unavailable",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "unavailable",
        "signatures_agree": "unavailable",
        "dependencies_provided": "unavailable"
      },
      "blames": {
        "soname_matches_declaration": "declaration",
        "soname_matches_requirement": "evidence",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "evidence",
        "signatures_agree": "evidence",
        "dependencies_provided": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "built",
        "native_side": "apt",
        "cooperation": "artifacts",
        "character": "artifact-centric, no bridge"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ]
      }
    },
    {
      "id": "4ea4a4-ocaml",
      "case": "zarith-ocaml-opam-apt",
      "project": "zarith",
      "scenario": "lib-fetched_ocaml_binding-fetched_binding_source_ocaml-fetched-1.14",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-28 15:50:54.222", "2026-09-28 15:51:01.748" ],
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
        "conf_probe": "warm",
        "discover": "observed",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "warm",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "undecided",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds",
        "gate_admits_the_world": "holds"
      },
      "badges": {
        "realize_sys": "partial",
        "conf_probe": "holds",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "conf_probe": [
          [ "gate_admits_the_world", "checked" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "conf_probe": [ 1, 1 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
      "dim": [ "src_sys", "staged_sys", "consumer_artifact" ],
      "lines": {
        "mod_lang": {
          "text": "zarith (4 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/zarith/fetch_binding/ocaml/inspect_lib-fetched_ocaml_binding-fetched_binding_source_ocaml-fetched-1.14.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libzarith.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/zarith/fetch_binding/ocaml/inspect_stub_lib-fetched_ocaml_binding-fetched_binding_source_ocaml-fetched-1.14.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "bridge": {
          "text": "conf-gmp",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/zarith/fetch_binding/ocaml_bridge/inspect_lib-fetched_ocaml_binding-fetched_binding_source_ocaml-fetched-1.14.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "cap": {
          "text": "gmp.pc",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/zarith/fetch_binding/ocaml_bridge/inspect_lib-fetched_ocaml_binding-fetched_binding_source_ocaml-fetched-1.14.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pkg_sys": {
          "text": "libgmp-dev",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/zarith/fetch_binding/ocaml_bridge/inspect_lib-fetched_ocaml_binding-fetched_binding_source_ocaml-fetched-1.14.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "lib_sys": {
          "text": "libgmp.so.10",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/zarith/probe_lib/inspect_lib-fetched_ocaml_binding-fetched_binding_source_ocaml-fetched-1.14.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "gmp.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "zarith",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_lang": {
          "text": "Zarith.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "zarith.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "lib_sys": {
          "kind": "render",
          "what": "the package is declared, but its installed VERSION is asked of the machine rendering this page — the run never recorded it (status.md §2.7 finding 2)",
          "at": "Canary_matrix.fetched_note → sys_pkg_version"
        },
        "src_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "bridge": {
          "kind": "run",
          "what": "_out/canary/projects/zarith/fetch_binding/ocaml_bridge/inspect_lib-fetched_ocaml_binding-fetched_binding_source_ocaml-fetched-1.14.json",
          "at": "Canary_overview_runs.bridge_sublabels"
        },
        "pkg_sys": {
          "kind": "run",
          "what": "_out/canary/projects/zarith/fetch_binding/ocaml_bridge/inspect_lib-fetched_ocaml_binding-fetched_binding_source_ocaml-fetched-1.14.json",
          "at": "Canary_overview_runs.bridge_sublabels"
        },
        "cap": {
          "kind": "run",
          "what": "_out/canary/projects/zarith/fetch_binding/ocaml_bridge/inspect_lib-fetched_ocaml_binding-fetched_binding_source_ocaml-fetched-1.14.json",
          "at": "Canary_overview_runs.bridge_sublabels"
        }
      },
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": { "stub_lang": "23 required", "lib_sys": "620 exports" },
      "row": {
        "sort": "zarith|4ea4a4-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-4ea4a4-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=4ea4a4-ocaml%40wsl_ubuntu\" data-key=\"4ea4a4-ocaml@wsl_ubuntu\"><b>zarith</b> 4ea4a4-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_sys: warm\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg\" title=\"libgmp-dev — 2:6.3.0+dfsg-2ubuntu6.1\">libgmp-dev</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-warm\" title=\"realize_sys, realize_hdr: warm\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libgmp.so.10 — apt libgmp-dev.2:6.3.0+dfsg\">libgmp.so.10 <span class=\"rt-x\">620 exports</span></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"gmp.h\">gmp.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-ok\" title=\"declared_symbols_exported: holds\">✓</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-gap\" title=\"soname_matches_declaration: undeclared — blame: declaration (read, but the project declared nothing to compare)\">no-decl</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libgmp.so.10 — apt libgmp-dev.2:6.3.0+dfsg\">libgmp.so.10</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-warm\" title=\"probe_lib: warm\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art rt-decl\" title=\"Zarith.git — F 1.14\">Zarith.git</td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"gmp.h\">gmp.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libzarith.a\">libzarith.a <span class=\"rt-x\">23 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libgmp.so.10 — apt libgmp-dev.2:6.3.0+dfsg\">libgmp.so.10</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"zarith (4 modules) — opam zarith\">zarith (4 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"zarith\">zarith</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg\" title=\"conf-gmp — installed 5\">conf-gmp</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-warm\" title=\"conf_probe: warm\">✓</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"gmp.pc — gmp 6.3.0\">gmp.pc</td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-ok\" title=\"gate_admits_the_world: holds\">✓</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"zarith (4 modules) — opam zarith\">zarith (4 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"zarith.mli\">zarith.mli</td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"zarith\">zarith</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "holds",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "undeclared",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds",
        "gate_admits_the_world": "holds"
      },
      "blames": {
        "soname_matches_declaration": "declaration",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence"
      },
      "observed": {
        "depends": "zarith's depends names conf-gmp",
        "conf_probe": "conf-gmp's check: pkg-config --print-errors --exists gmp — holds",
        "depext": "conf-gmp maps to libgmp-dev",
        "resolve_sys": "installed here: libgmp-dev 2:6.3.0+dfsg-2ubuntu6.1",
        "realize_cap": "libgmp-dev ships /usr/lib/x86_64-linux-gnu/pkgconfig/gmp.pc",
        "discover": "pkg-config gmp → 6.3.0 in /usr/lib/x86_64-linux-gnu"
      },
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "apt",
        "cooperation": "conf",
        "character": "symbolic package bridge + artifact validation"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ],
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "7a10f8-ocaml",
      "case": "cairo-ocaml-opam-vendored",
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
        "depends": "warm",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "unevaluated",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "unevaluated",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "unevaluated",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "violated"
      },
      "badges": {
        "realize_sys": "unevaluated",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "violated"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "bridge": { "label": "conf-cairo", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "cairo2", "from": "declared" }
      },
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "lines": {
        "mod_lang": {
          "text": "cairo2 (1 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/cairo/fetch_binding/ocaml/inspect_source-fetched-1.18.0_lib-vendored-dev_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libcairo_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/cairo/fetch_binding/ocaml/inspect_stub_source-fetched-1.18.0_lib-vendored-dev_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "libcairo2-dev",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "cairo.h, cairo-ft.h, cairo-pdf.h, cairo-ps.h, cairo-svg.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the declared C API's headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "cairo.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-cairo",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the package gate the project routes (pr_pm_gates, read by Canary_topology.join_of)",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "cairo2",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [ "staged_sys", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "source_is_declared_ref",
        "build_tree_configured_for_source", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": { "stub_lang": "223 required" },
      "row": {
        "sort": "cairo|7a10f8-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-7a10f8-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=7a10f8-ocaml%40wsl_ubuntu\" data-key=\"7a10f8-ocaml@wsl_ubuntu\"><b>cairo</b> 7a10f8-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_sys: warm\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"libcairo2-dev\">libcairo2-dev</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-warm\" title=\"realize_sys, realize_hdr: warm\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art\" title=\"V:d\">V:d</td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"cairo.h, cairo-ft.h, cairo-pdf.h, cairo-ps.h, cairo-svg.h\">cairo.h, cairo-ft.h, cairo-pdf.h, cairo-ps.h, cairo-svg.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_symbols_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_versions_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"soname_matches_declaration: not evaluated in any recorded run\">·</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-off\"></td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"cairo.h, cairo-ft.h, cairo-pdf.h, cairo-ps.h, cairo-svg.h\">cairo.h, cairo-ft.h, cairo-pdf.h, cairo-ps.h, cairo-svg.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libcairo_stubs.a\">libcairo_stubs.a <span class=\"rt-x\">223 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"V:d\"></td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-bad\" title=\"dependencies_provided: violated\">✗</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"cairo2 (1 modules) — opam cairo2\">cairo2 (1 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"cairo2\">cairo2</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-cairo\">conf-cairo</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: not evaluated in any recorded run\">·</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"cairo2 (1 modules) — opam cairo2\">cairo2 (1 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"cairo2\">cairo2</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "violated"
      },
      "blames": {
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "vendored",
        "cooperation": "gated_local",
        "character": "⚠ bridge still gates, against a system this world does not use"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ],
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "7ac7f1-ocaml",
      "case": "cairo-ocaml-opam-apt",
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
        "depends": "warm",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "unevaluated",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "unevaluated",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "unevaluated",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "violated"
      },
      "badges": {
        "realize_sys": "unevaluated",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "violated"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "bridge": { "label": "conf-cairo", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "cairo2", "from": "declared" }
      },
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "lines": {
        "mod_lang": {
          "text": "cairo2 (1 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/cairo/fetch_binding/ocaml/inspect_source-fetched-1.18.0_lib-fetched_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libcairo_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/cairo/fetch_binding/ocaml/inspect_stub_source-fetched-1.18.0_lib-fetched_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "lib_sys": {
          "text": "libcairo.so.2",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/cairo/probe_lib/inspect_source-fetched-1.18.0_lib-fetched_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "libcairo2-dev",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "cairo.h, cairo-ft.h, cairo-pdf.h, cairo-ps.h, cairo-svg.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the declared C API's headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "cairo.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-cairo",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the package gate the project routes (pr_pm_gates, read by Canary_topology.join_of)",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "cairo2",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "render",
          "what": "the package is declared, but its installed VERSION is asked of the machine rendering this page — the run never recorded it (status.md §2.7 finding 2)",
          "at": "Canary_matrix.fetched_note → sys_pkg_version"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": { "stub_lang": "223 required", "lib_sys": "420 exports" },
      "row": {
        "sort": "cairo|7ac7f1-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-7ac7f1-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=7ac7f1-ocaml%40wsl_ubuntu\" data-key=\"7ac7f1-ocaml@wsl_ubuntu\"><b>cairo</b> 7ac7f1-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_sys: warm\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"libcairo2-dev\">libcairo2-dev</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-warm\" title=\"realize_sys, realize_hdr: warm\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libcairo.so.2 — apt libcairo2-dev.1.18.0\">libcairo.so.2 <span class=\"rt-x\">420 exports</span></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"cairo.h, cairo-ft.h, cairo-pdf.h, cairo-ps.h, cairo-svg.h\">cairo.h, cairo-ft.h, cairo-pdf.h, cairo-ps.h, cairo-svg.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_symbols_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_versions_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"soname_matches_declaration: not evaluated in any recorded run\">·</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libcairo.so.2 — apt libcairo2-dev.1.18.0\">libcairo.so.2</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"cairo.h, cairo-ft.h, cairo-pdf.h, cairo-ps.h, cairo-svg.h\">cairo.h, cairo-ft.h, cairo-pdf.h, cairo-ps.h, cairo-svg.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libcairo_stubs.a\">libcairo_stubs.a <span class=\"rt-x\">223 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libcairo.so.2 — apt libcairo2-dev.1.18.0\">libcairo.so.2</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-bad\" title=\"dependencies_provided: violated\">✗</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"cairo2 (1 modules) — opam cairo2\">cairo2 (1 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"cairo2\">cairo2</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-cairo\">conf-cairo</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: not evaluated in any recorded run\">·</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"cairo2 (1 modules) — opam cairo2\">cairo2 (1 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"cairo2\">cairo2</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "violated"
      },
      "blames": {
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "apt",
        "cooperation": "conf",
        "character": "symbolic package bridge + artifact validation"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ],
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "1406f0-ocaml",
      "case": "libffi-ocaml-opam-vendored",
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
        "depends": "warm",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "unevaluated",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "unevaluated",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "unevaluated",
        "required_versions_exported": "holds",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds"
      },
      "badges": {
        "realize_sys": "unevaluated",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "holds"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "bridge": { "label": "conf-libffi", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "ctypes-foreign", "from": "declared" }
      },
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "lines": {
        "mod_lang": {
          "text": "ctypes-foreign (9 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/libffi/fetch_binding/ocaml/inspect_source-fetched-3.8.0_lib-vendored-dev_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libctypes_foreign_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/libffi/fetch_binding/ocaml/inspect_stub_source-fetched-3.8.0_lib-vendored-dev_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "libffi-dev",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "ffi.h, ffitarget.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the declared C API's headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "libffi.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-libffi",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the package gate the project routes (pr_pm_gates, read by Canary_topology.join_of)",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "ctypes-foreign",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [ "staged_sys", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "source_is_declared_ref",
        "build_tree_configured_for_source", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": { "stub_lang": "17 required" },
      "row": {
        "sort": "libffi|1406f0-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-1406f0-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=1406f0-ocaml%40wsl_ubuntu\" data-key=\"1406f0-ocaml@wsl_ubuntu\"><b>libffi</b> 1406f0-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_sys: warm\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"libffi-dev\">libffi-dev</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-warm\" title=\"realize_sys, realize_hdr: warm\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art\" title=\"V:d\">V:d</td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"ffi.h, ffitarget.h\">ffi.h, ffitarget.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_symbols_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_versions_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"soname_matches_declaration: not evaluated in any recorded run\">·</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-off\"></td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"ffi.h, ffitarget.h\">ffi.h, ffitarget.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libctypes_foreign_stubs.a\">libctypes_foreign_stubs.a <span class=\"rt-x\">17 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"V:d\"></td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_versions_exported: holds\">✓</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"ctypes-foreign (9 modules) — opam ctypes-foreign\">ctypes-foreign (9 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"ctypes-foreign\">ctypes-foreign</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-libffi\">conf-libffi</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: not evaluated in any recorded run\">·</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"ctypes-foreign (9 modules) — opam ctypes-foreign\">ctypes-foreign (9 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"ctypes-foreign\">ctypes-foreign</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "holds",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds"
      },
      "blames": { "signatures_agree": "evidence" },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "vendored",
        "cooperation": "gated_local",
        "character": "⚠ bridge still gates, against a system this world does not use"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ],
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "0a184a-ocaml",
      "case": "libffi-ocaml-opam-apt",
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
        "depends": "warm",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "unevaluated",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "unevaluated",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "unevaluated",
        "required_versions_exported": "holds",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds"
      },
      "badges": {
        "realize_sys": "unevaluated",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "holds"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "bridge": { "label": "conf-libffi", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "ctypes-foreign", "from": "declared" }
      },
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "lines": {
        "mod_lang": {
          "text": "ctypes-foreign (9 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/libffi/fetch_binding/ocaml/inspect_source-fetched-3.8.0_lib-fetched_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "stub_lang": {
          "text": "libctypes_foreign_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/libffi/fetch_binding/ocaml/inspect_stub_source-fetched-3.8.0_lib-fetched_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "lib_sys": {
          "text": "libffi.so.8",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/libffi/probe_lib/inspect_source-fetched-3.8.0_lib-fetched_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "libffi-dev",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "ffi.h, ffitarget.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the declared C API's headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "libffi.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-libffi",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the package gate the project routes (pr_pm_gates, read by Canary_topology.join_of)",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "ctypes-foreign",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "render",
          "what": "the package is declared, but its installed VERSION is asked of the machine rendering this page — the run never recorded it (status.md §2.7 finding 2)",
          "at": "Canary_matrix.fetched_note → sys_pkg_version"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": { "stub_lang": "17 required", "lib_sys": "42 exports" },
      "row": {
        "sort": "libffi|0a184a-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-0a184a-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=0a184a-ocaml%40wsl_ubuntu\" data-key=\"0a184a-ocaml@wsl_ubuntu\"><b>libffi</b> 0a184a-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_sys: warm\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"libffi-dev\">libffi-dev</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-warm\" title=\"realize_sys, realize_hdr: warm\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libffi.so.8 — apt libffi-dev.3.4.6\">libffi.so.8 <span class=\"rt-x\">42 exports</span></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"ffi.h, ffitarget.h\">ffi.h, ffitarget.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_symbols_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_versions_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"soname_matches_declaration: not evaluated in any recorded run\">·</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libffi.so.8 — apt libffi-dev.3.4.6\">libffi.so.8</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"ffi.h, ffitarget.h\">ffi.h, ffitarget.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libctypes_foreign_stubs.a\">libctypes_foreign_stubs.a <span class=\"rt-x\">17 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libffi.so.8 — apt libffi-dev.3.4.6\">libffi.so.8</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_versions_exported: holds\">✓</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"ctypes-foreign (9 modules) — opam ctypes-foreign\">ctypes-foreign (9 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"ctypes-foreign\">ctypes-foreign</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-libffi\">conf-libffi</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: not evaluated in any recorded run\">·</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"ctypes-foreign (9 modules) — opam ctypes-foreign\">ctypes-foreign (9 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"ctypes-foreign\">ctypes-foreign</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "holds",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds"
      },
      "blames": { "signatures_agree": "evidence" },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "apt",
        "cooperation": "conf",
        "character": "symbolic package bridge + artifact validation"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ],
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "657774-ocaml",
      "case": "zlib-ocaml-opam-vendored",
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
        "depends": "warm",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "warm",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "undecided",
        "required_symbols_exported": "undecided",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds"
      },
      "badges": {
        "realize_sys": "partial",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "bridge": { "label": "conf-zlib", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "camlzip", "from": "declared" }
      },
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "lines": {
        "mod_lang": {
          "text": "zip (3 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/zlib/fetch_binding/ocaml/inspect_source-fetched-1.3.1_lib-vendored-dev_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "zlib1g-dev",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "lib_sys": {
          "text": "libz.so.1",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the declared C API's soname",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "zlib.h, zconf.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the declared C API's headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "zlib.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-zlib",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the package gate the project routes (pr_pm_gates, read by Canary_topology.join_of)",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "camlzip",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [ "staged_sys", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "source_is_declared_ref",
        "build_tree_configured_for_source", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": {},
      "row": {
        "sort": "zlib|657774-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-657774-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=657774-ocaml%40wsl_ubuntu\" data-key=\"657774-ocaml@wsl_ubuntu\"><b>zlib</b> 657774-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_sys: warm\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"zlib1g-dev\">zlib1g-dev</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-warm\" title=\"realize_sys, realize_hdr: warm\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-decl\" title=\"libz.so.1 — V:d\">libz.so.1</td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"zlib.h, zconf.h\">zlib.h, zconf.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-gap\" title=\"declared_symbols_exported: inconclusive — blame: version (one declared value, several version points — spec)\">no-ref</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-off\"></td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"zlib.h, zconf.h\">zlib.h, zconf.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libz.so.1 — V:d\">libz.so.1</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_symbols_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"zip (3 modules) — opam camlzip\">zip (3 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"camlzip\">camlzip</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-zlib\">conf-zlib</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: not evaluated in any recorded run\">·</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"zip (3 modules) — opam camlzip\">zip (3 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"camlzip\">camlzip</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-warm\" title=\"run_packaged: warm\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "inconclusive",
        "required_symbols_exported": "unavailable",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds"
      },
      "blames": {
        "declared_symbols_exported": "version",
        "required_symbols_exported": "evidence",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "vendored",
        "cooperation": "gated_local",
        "character": "⚠ bridge still gates, against a system this world does not use"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ],
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "d668a4-ocaml",
      "case": "zlib-ocaml-opam-apt",
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
        "depends": "warm",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "warm",
        "install_lang": "warm",
        "install_surf": "warm",
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "warm",
        "run": "absent",
        "run_packaged": "warm",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "undecided",
        "required_symbols_exported": "undecided",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "undecided",
        "required_versions_exported": "undecided",
        "signatures_agree": "undecided",
        "dependencies_provided": "holds"
      },
      "badges": {
        "realize_sys": "partial",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "partial"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "bridge": { "label": "conf-zlib", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "camlzip", "from": "declared" }
      },
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "lines": {
        "mod_lang": {
          "text": "zip (3 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/zlib/fetch_binding/ocaml/inspect_source-fetched-1.3.1_lib-fetched_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "lib_sys": {
          "text": "libz.so.1",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/zlib/probe_lib/inspect_source-fetched-1.3.1_lib-fetched_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "zlib1g-dev",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "zlib.h, zconf.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the declared C API's headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "zlib.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-zlib",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the package gate the project routes (pr_pm_gates, read by Canary_topology.join_of)",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "camlzip",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "render",
          "what": "the package is declared, but its installed VERSION is asked of the machine rendering this page — the run never recorded it (status.md §2.7 finding 2)",
          "at": "Canary_matrix.fetched_note → sys_pkg_version"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": { "lib_sys": "102 exports" },
      "row": {
        "sort": "zlib|d668a4-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-d668a4-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=d668a4-ocaml%40wsl_ubuntu\" data-key=\"d668a4-ocaml@wsl_ubuntu\"><b>zlib</b> d668a4-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_sys: warm\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"zlib1g-dev\">zlib1g-dev</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-warm\" title=\"realize_sys, realize_hdr: warm\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libz.so.1 — apt zlib1g-dev.1:1.3.dfsg\">libz.so.1 <span class=\"rt-x\">102 exports</span></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"zlib.h, zconf.h\">zlib.h, zconf.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-gap\" title=\"declared_symbols_exported: inconclusive — blame: version (one declared value, several version points — spec)\">no-ref</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-gap\" title=\"declared_versions_exported: vacuous — blame: vacuous (both sides read, neither has anything of this kind — fine)\">none</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-ok\" title=\"soname_matches_declaration: holds\">✓</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libz.so.1 — apt zlib1g-dev.1:1.3.dfsg\">libz.so.1</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-warm\" title=\"probe_lib: warm\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"zlib.h, zconf.h\">zlib.h, zconf.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libz.so.1 — apt zlib1g-dev.1:1.3.dfsg\">libz.so.1</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"dependencies_provided: holds\">✓</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_symbols_exported: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-gap\" title=\"required_versions_exported: inconclusive — blame: vacuous (both sides read, neither has anything of this kind — fine)\">no-ref</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"zip (3 modules) — opam camlzip\">zip (3 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_lang: warm\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"camlzip\">camlzip</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-warm\" title=\"depends: warm\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-zlib\">conf-zlib</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: not evaluated in any recorded run\">·</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-warm\" title=\"install_lang, install_surf: warm\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"zip (3 modules) — opam camlzip\">zip (3 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"camlzip\">camlzip</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-warm\" title=\"run_packaged: warm\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "declared_symbols_exported": "inconclusive",
        "required_symbols_exported": "unavailable",
        "api_names_present": "holds",
        "soname_matches_declaration": "holds",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "inconclusive",
        "signatures_agree": "unavailable",
        "dependencies_provided": "holds"
      },
      "blames": {
        "declared_symbols_exported": "version",
        "required_symbols_exported": "evidence",
        "declared_versions_exported": "vacuous",
        "required_versions_exported": "vacuous",
        "signatures_agree": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "apt",
        "cooperation": "conf",
        "character": "symbolic package bridge + artifact validation"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ],
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "ff020b-ocaml",
      "case": "zstd-ocaml-opam-vendored",
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
        "depends": "ran",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "ran",
        "install_lang": "ran",
        "install_surf": "ran",
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "absent",
        "run": "absent",
        "run_packaged": "fail",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "unevaluated",
        "required_symbols_exported": "unevaluated",
        "api_names_present": "unevaluated",
        "soname_matches_declaration": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_versions_exported": "unevaluated",
        "signatures_agree": "unevaluated",
        "dependencies_provided": "unevaluated"
      },
      "badges": {
        "realize_sys": "unevaluated",
        "install_surf": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "bridge": { "label": "conf-zstd", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "zstd", "from": "declared" }
      },
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "lines": {
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "libzstd-dev",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "lib_sys": {
          "text": "libzstd.so.1",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the declared C API's soname",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "zstd.h, zstd_errors.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the declared C API's headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "zstd.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-zstd",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the package gate the project routes (pr_pm_gates, read by Canary_topology.join_of)",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "zstd",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [ "staged_sys", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "source_is_declared_ref",
        "build_tree_configured_for_source", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": {},
      "row": {
        "sort": "zstd|ff020b-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-ff020b-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=ff020b-ocaml%40wsl_ubuntu\" data-key=\"ff020b-ocaml@wsl_ubuntu\"><b>zstd</b> ff020b-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-ok\" title=\"resolve_sys: ran\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"libzstd-dev\">libzstd-dev</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-ok\" title=\"realize_sys, realize_hdr: ran\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-decl\" title=\"libzstd.so.1 — V:d\">libzstd.so.1</td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"zstd.h, zstd_errors.h\">zstd.h, zstd_errors.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_symbols_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_versions_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"soname_matches_declaration: not evaluated in any recorded run\">·</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-off\"></td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"zstd.h, zstd_errors.h\">zstd.h, zstd_errors.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: not evaluated in any recorded run\">·</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libzstd.so.1 — V:d\">libzstd.so.1</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"dependencies_provided: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_symbols_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_versions_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"soname_matches_requirement: not evaluated in any recorded run\">·</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"opam zstd\">opam zstd</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-ok\" title=\"resolve_lang: ran\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"zstd\">zstd</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-ok\" title=\"depends: ran\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-zstd\">conf-zstd</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: not evaluated in any recorded run\">·</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-ok\" title=\"install_lang, install_surf: ran\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"opam zstd\"></td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-dim\" title=\"api_names_present: not evaluated in any recorded run\">·</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"zstd\">zstd</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-bad\" title=\"run_packaged: fail\">✗</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {},
      "blames": {},
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "vendored",
        "cooperation": "gated_local",
        "character": "⚠ bridge still gates, against a system this world does not use"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ],
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "ff7b9d-ocaml",
      "case": "zstd-ocaml-opam-apt",
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
        "depends": "ran",
        "conf_probe": "absent",
        "discover": "not_ours",
        "resolve_lang": "ran",
        "install_lang": "ran",
        "install_surf": "ran",
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "ran",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "unevaluated",
        "required_symbols_exported": "unevaluated",
        "api_names_present": "unevaluated",
        "soname_matches_declaration": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_versions_exported": "unevaluated",
        "signatures_agree": "unevaluated",
        "dependencies_provided": "unevaluated"
      },
      "badges": {
        "realize_sys": "unevaluated",
        "install_surf": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
        "bridge": { "label": "conf-zstd", "from": "declared" },
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "zstd", "from": "declared" }
      },
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "lines": {
        "mod_lang": {
          "text": "zstd (1 modules)",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/zstd/probe_binding/ocaml/inspect_source-fetched-1.5.7_lib-fetched_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "lib_sys": {
          "text": "libzstd.so.1",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/zstd/probe_lib/inspect_source-fetched-1.5.7_lib-fetched_ocaml_binding-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "libzstd-dev",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "zstd.h, zstd_errors.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the declared C API's headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "zstd.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-zstd",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the package gate the project routes (pr_pm_gates, read by Canary_topology.join_of)",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "zstd",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "render",
          "what": "the package is declared, but its installed VERSION is asked of the machine rendering this page — the run never recorded it (status.md §2.7 finding 2)",
          "at": "Canary_matrix.fetched_note → sys_pkg_version"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": { "lib_sys": "185 exports" },
      "row": {
        "sort": "zstd|ff7b9d-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-ff7b9d-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=ff7b9d-ocaml%40wsl_ubuntu\" data-key=\"ff7b9d-ocaml@wsl_ubuntu\"><b>zstd</b> ff7b9d-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-ok\" title=\"resolve_sys: ran\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"libzstd-dev\">libzstd-dev</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-ok\" title=\"realize_sys, realize_hdr: ran\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libzstd.so.1 — apt libzstd-dev.1.5.5+dfsg2\">libzstd.so.1 <span class=\"rt-x\">185 exports</span></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"zstd.h, zstd_errors.h\">zstd.h, zstd_errors.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_symbols_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_versions_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"soname_matches_declaration: not evaluated in any recorded run\">·</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libzstd.so.1 — apt libzstd-dev.1.5.5+dfsg2\">libzstd.so.1</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"zstd.h, zstd_errors.h\">zstd.h, zstd_errors.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: not evaluated in any recorded run\">·</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libzstd.so.1 — apt libzstd-dev.1.5.5+dfsg2\">libzstd.so.1</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"dependencies_provided: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_symbols_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_versions_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"soname_matches_requirement: not evaluated in any recorded run\">·</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"zstd (1 modules) — opam zstd\">zstd (1 modules)</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-ok\" title=\"resolve_lang: ran\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"zstd\">zstd</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-ok\" title=\"depends: ran\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-zstd\">conf-zstd</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: not evaluated in any recorded run\">·</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-ok\" title=\"install_lang, install_surf: ran\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"zstd (1 modules) — opam zstd\">zstd (1 modules)</td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-dim\" title=\"api_names_present: not evaluated in any recorded run\">·</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"zstd\">zstd</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-ok\" title=\"run_packaged: ran\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {},
      "blames": {},
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "apt",
        "cooperation": "conf",
        "character": "symbolic package bridge + artifact validation"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ],
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "7b508c-ocaml",
      "case": "ssl-ocaml-opam-apt",
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
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "fail",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "unevaluated",
        "required_symbols_exported": "holds",
        "api_names_present": "violated",
        "soname_matches_declaration": "unevaluated",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "unevaluated",
        "required_versions_exported": "holds",
        "signatures_agree": "undecided",
        "dependencies_provided": "violated"
      },
      "badges": {
        "realize_sys": "unevaluated",
        "install_surf": "violated",
        "build_stub": "undecided",
        "link_mod": "violated"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "lines": {
        "stub_lang": {
          "text": "libssl_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/ssl/fetch_binding/ocaml/inspect_stub_source-fetched_lib-fetched_ocaml_binding-fetched-0.6.0_app-vendored-stable.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "lib_sys": {
          "text": "libssl.so.3",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/ssl/probe_lib/inspect_source-fetched_lib-fetched_ocaml_binding-fetched-0.6.0_app-vendored-stable.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "libssl-dev",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "ssl.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "openssl.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-libssl",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "ssl",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "ssl.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "render",
          "what": "the package is declared, but its installed VERSION is asked of the machine rendering this page — the run never recorded it (status.md §2.7 finding 2)",
          "at": "Canary_matrix.fetched_note → sys_pkg_version"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": {
        "surf_lang": "4 modules",
        "stub_lang": "43 required",
        "lib_sys": "519 exports"
      },
      "row": {
        "sort": "ssl|7b508c-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-7b508c-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=7b508c-ocaml%40wsl_ubuntu\" data-key=\"7b508c-ocaml@wsl_ubuntu\"><b>ssl</b> 7b508c-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_sys: warm\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"libssl-dev\">libssl-dev</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-warm\" title=\"realize_sys, realize_hdr: warm\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libssl.so.3 — apt libssl-dev.3.0.13\">libssl.so.3 <span class=\"rt-x\">519 exports</span></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"ssl.h\">ssl.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_symbols_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_versions_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"soname_matches_declaration: not evaluated in any recorded run\">·</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libssl.so.3 — apt libssl-dev.3.0.13\">libssl.so.3</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"ssl.h\">ssl.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libssl_stubs.a\">libssl_stubs.a <span class=\"rt-x\">43 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libssl.so.3 — apt libssl-dev.3.0.13\">libssl.so.3</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-bad\" title=\"dependencies_provided: violated\">✗</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_versions_exported: holds\">✓</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"opam ssl.0.6.0\">opam ssl.0.6.0</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-ok\" title=\"resolve_lang: ran\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"ssl\">ssl</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-ok\" title=\"depends: ran\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-libssl\">conf-libssl</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: not evaluated in any recorded run\">·</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-ok\" title=\"install_lang, install_surf: ran\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"opam ssl.0.6.0\"></td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"ssl.mli\">ssl.mli <span class=\"rt-x\">4 modules</span></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-bad\" title=\"api_names_present: violated — blame: version (one declared value, several version points — spec)\">✗</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"ssl\">ssl</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-bad\" title=\"run_packaged: fail\">✗</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "required_symbols_exported": "holds",
        "api_names_present": "violated",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "holds",
        "signatures_agree": "unavailable",
        "dependencies_provided": "violated"
      },
      "blames": {
        "api_names_present": "version",
        "signatures_agree": "evidence"
      },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "apt",
        "cooperation": "conf",
        "character": "symbolic package bridge + artifact validation"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ],
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "8f247d-ocaml",
      "case": "ssl-ocaml-opam-apt",
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
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "ran",
        "run": "absent",
        "run_packaged": "fail",
        "same_program": "claim"
      },
      "claims": {
        "declared_symbols_exported": "unevaluated",
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_declaration": "unevaluated",
        "soname_matches_requirement": "holds",
        "declared_versions_exported": "unevaluated",
        "required_versions_exported": "holds",
        "signatures_agree": "undecided",
        "dependencies_provided": "violated"
      },
      "badges": {
        "realize_sys": "unevaluated",
        "install_surf": "holds",
        "build_stub": "undecided",
        "link_mod": "violated"
      },
      "edge_claims": {
        "realize_sys": [
          [ "declared_symbols_exported", "checked" ],
          [ "soname_matches_declaration", "checked" ],
          [ "declared_versions_exported", "checked" ],
          [ "exports_accounted_for", "placeholder" ]
        ],
        "depext": [ [ "depext_names_the_provided_package", "placeholder" ] ],
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "discover": [ [ "discovery_matches_link", "placeholder" ] ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "realize_sys": [ 3, 1 ],
        "depext": [ 0, 1 ],
        "depends": [ 0, 2 ],
        "discover": [ 0, 1 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
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
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "lines": {
        "stub_lang": {
          "text": "libssl_stubs.a",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/ssl/fetch_binding/ocaml/inspect_stub_source-fetched_lib-fetched_ocaml_binding-fetched-0.7.0_app-vendored-stable.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "lib_sys": {
          "text": "libssl.so.3",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/ssl/probe_lib/inspect_source-fetched_lib-fetched_ocaml_binding-fetched-0.7.0_app-vendored-stable.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "pm_sys": {
          "text": "apt",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider is a system package: this platform's",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_sys": {
          "text": "libssl-dev",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library row's provider (Sys_pkg), named for this platform",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "hdr_sys": {
          "text": "ssl.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_sys": {
          "text": "openssl.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the library source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "conf-libssl",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "ssl",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "ssl.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "src_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "lib_sys": {
          "kind": "render",
          "what": "the package is declared, but its installed VERSION is asked of the machine rendering this page — the run never recorded it (status.md §2.7 finding 2)",
          "at": "Canary_matrix.fetched_note → sys_pkg_version"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "repack_preserves_api",
        "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "declared_gate_matches_package", "gate_bounds_the_library",
        "depext_names_the_provided_package"
      ],
      "counts": {
        "surf_lang": "4 modules",
        "stub_lang": "43 required",
        "lib_sys": "519 exports"
      },
      "row": {
        "sort": "ssl|8f247d-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-8f247d-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=8f247d-ocaml%40wsl_ubuntu\" data-key=\"8f247d-ocaml@wsl_ubuntu\"><b>ssl</b> 8f247d-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-decl\" title=\"apt\">apt</td>",
          "fetch_lib|p|resolve": "<td class=\"rt-p rt-warm\" title=\"resolve_sys: warm\">✓</td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-decl\" title=\"libssl-dev\">libssl-dev</td>",
          "fetch_lib|p|realize": "<td class=\"rt-p rt-warm\" title=\"realize_sys, realize_hdr: warm\">✓</td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libssl.so.3 — apt libssl-dev.3.0.13\">libssl.so.3 <span class=\"rt-x\">519 exports</span></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"ssl.h\">ssl.h</td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_symbols_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"declared_versions_exported: not evaluated in any recorded run\">·</td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-c rt-dim\" title=\"soname_matches_declaration: not evaluated in any recorded run\">·</td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libssl.so.3 — apt libssl-dev.3.0.13\">libssl.so.3</td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-ok\" title=\"probe_lib: ran\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art\" title=\"\"></td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-rep\" title=\"ssl.h\">ssl.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-gap\" title=\"signatures_agree: unavailable — blame: evidence (nothing wrote the inspection this reads — wiring)\">no-evid</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art\" title=\"libssl_stubs.a\">libssl_stubs.a <span class=\"rt-x\">43 required</span></td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libssl.so.3 — apt libssl-dev.3.0.13\">libssl.so.3</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-bad\" title=\"dependencies_provided: violated\">✗</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_symbols_exported: holds\">✓</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"required_versions_exported: holds\">✓</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-ok\" title=\"soname_matches_requirement: holds\">✓</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"opam ssl.0.7.0\">opam ssl.0.7.0</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-ok\" title=\"resolve_lang: ran\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"ssl\">ssl</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-ok\" title=\"depends: ran\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"conf-libssl\">conf-libssl</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg\" title=\"\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: not evaluated in any recorded run\">·</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-ok\" title=\"install_lang, install_surf: ran\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"opam ssl.0.7.0\"></td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"ssl.mli\">ssl.mli <span class=\"rt-x\">4 modules</span></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-ok\" title=\"api_names_present: holds\">✓</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"ssl\">ssl</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-bad\" title=\"run_packaged: fail\">✗</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {
        "required_symbols_exported": "holds",
        "api_names_present": "holds",
        "soname_matches_requirement": "holds",
        "required_versions_exported": "holds",
        "signatures_agree": "unavailable",
        "dependencies_provided": "violated"
      },
      "blames": { "signatures_agree": "evidence" },
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "apt",
        "cooperation": "conf",
        "character": "symbolic package bridge + artifact validation"
      },
      "placeholders": {
        "resolve_sys": [
          {
            "unseen": "not_yet",
            "text": "apt resolve: the version apt chose, and the pins and priorities that chose it; not recorded yet — `apt-cache policy <package>` answers both, in the world the run is in"
          }
        ],
        "discover": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "0dc978-ocaml",
      "case": "torch-ocaml-opam-opam",
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
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "warm",
        "run": "absent",
        "run_packaged": "xfail",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "unevaluated",
        "api_names_present": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "signatures_agree": "unevaluated",
        "dependencies_provided": "unevaluated"
      },
      "badges": {
        "install_surf": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "edge_claims": {
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "depends": [ 0, 2 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
      },
      "nodes": {
        "lib_sys": "opam libtorch.2.1.2",
        "src_lang": "F",
        "mod_lang": "opam torch.v0.17.0"
      },
      "unplaced": {
        "fetch_lib": "the library comes from a language package manager: no edge from there",
        "fetch_lib_opam_plan": "the library comes from a language package manager: no edge from there",
        "fetch_lib_opam_solver": "the library comes from a language package manager: no edge from there"
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
        "pm_sys", "pkg_sys", "src_sys", "staged_sys", "cap",
        "consumer_artifact"
      ],
      "lines": {
        "lib_sys": {
          "text": "libtorch_cpu.so",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/torch/probe_lib/inspect_lib-fetched-2.1.2_ocaml_binding-fetched-v0.17.0_binding_source_ocaml-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "hdr_sys": {
          "text": "torch.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "depext: libtorch >= 2.1.0 & < 2.2.0",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "torch",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_lang": {
          "text": "torch.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "libtorch_core_stubs.a",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "torch.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "src_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "pm_sys", "pkg_sys", "src_sys", "staged_sys", "cap", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "build_lib",
        "build_hdr", "stage", "depext", "conf_probe", "discover"
      ],
      "candidates": [
        "signatures_match_debug_info", "package_contains_declared_files",
        "repack_preserves_api", "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "declared_gate_matches_package",
        "gate_bounds_the_library"
      ],
      "counts": { "surf_lang": "19 modules", "lib_sys": "75526 exports" },
      "row": {
        "sort": "torch|0dc978-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-0dc978-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=0dc978-ocaml%40wsl_ubuntu\" data-key=\"0dc978-ocaml@wsl_ubuntu\"><b>torch</b> 0dc978-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libtorch_cpu.so — opam libtorch.2.1.2\">libtorch_cpu.so <span class=\"rt-x\">75526 exports</span></td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-warm\" title=\"probe_lib: warm\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art rt-decl\" title=\"torch.git — F\">torch.git</td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"torch.h\">torch.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: not evaluated in any recorded run\">·</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"libtorch_core_stubs.a\">libtorch_core_stubs.a</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libtorch_cpu.so — opam libtorch.2.1.2\">libtorch_cpu.so</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"dependencies_provided: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_symbols_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_versions_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"soname_matches_requirement: not evaluated in any recorded run\">·</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"opam torch.v0.17.0\">opam torch.v0.17.0</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-xf\" title=\"resolve_lang: xfail\">xf</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"torch\">torch</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-xf\" title=\"depends: xfail\">xf</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"depext: libtorch &gt;= 2.1.0 &amp; &lt; 2.2.0\">depext: libtorch &gt;= 2.1.0 &amp; &lt; 2.2.0</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: not evaluated in any recorded run\">·</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-xf\" title=\"install_lang, install_surf: xfail\">xf</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"opam torch.v0.17.0\"></td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"torch.mli\">torch.mli <span class=\"rt-x\">19 modules</span></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-dim\" title=\"api_names_present: not evaluated in any recorded run\">·</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"torch\">torch</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-xf\" title=\"run_packaged: xfail\">xf</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {},
      "blames": {},
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "opam",
        "cooperation": "unified",
        "character": "unified package universe"
      },
      "placeholders": {
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    },
    {
      "id": "e1d373-ocaml",
      "case": "torch-ocaml-opam-opam",
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
        "build_stub": "inside",
        "link_mod": "inside",
        "pack": "absent",
        "probe_lib": "warm",
        "run": "absent",
        "run_packaged": "warm",
        "same_program": "claim"
      },
      "claims": {
        "required_symbols_exported": "unevaluated",
        "api_names_present": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "signatures_agree": "unevaluated",
        "dependencies_provided": "unevaluated"
      },
      "badges": {
        "install_surf": "unevaluated",
        "build_stub": "unevaluated",
        "link_mod": "unevaluated"
      },
      "edge_claims": {
        "depends": [
          [ "declared_gate_matches_package", "placeholder" ],
          [ "gate_bounds_the_library", "placeholder" ]
        ],
        "resolve_lang": [ [ "package_resolution_suffices", "placeholder" ] ],
        "install_lang": [
          [ "package_contains_declared_files", "placeholder" ]
        ],
        "install_surf": [ [ "api_names_present", "checked" ] ],
        "build_stub": [
          [ "signatures_agree", "checked" ],
          [ "signatures_match_debug_info", "placeholder" ]
        ],
        "link_mod": [
          [ "required_symbols_exported", "checked" ],
          [ "soname_matches_requirement", "checked" ],
          [ "required_versions_exported", "checked" ],
          [ "dependencies_provided", "checked" ],
          [ "compatibility_version_satisfied", "placeholder" ]
        ],
        "run_packaged": [ [ "package_resolution_suffices", "placeholder" ] ],
        "same_program": [ [ "package_resolution_suffices", "placeholder" ] ]
      },
      "edge_counts": {
        "depends": [ 0, 2 ],
        "resolve_lang": [ 0, 1 ],
        "install_lang": [ 0, 1 ],
        "install_surf": [ 1, 0 ],
        "build_stub": [ 1, 1 ],
        "link_mod": [ 4, 1 ],
        "run_packaged": [ 0, 1 ],
        "same_program": [ 0, 1 ]
      },
      "nodes": {
        "lib_sys": "opam libtorch.2.1.2",
        "src_lang": "F",
        "mod_lang": "opam torch.v0.17.0-canary1"
      },
      "unplaced": {
        "fetch_lib": "the library comes from a language package manager: no edge from there",
        "fetch_lib_opam_plan": "the library comes from a language package manager: no edge from there",
        "fetch_lib_opam_solver": "the library comes from a language package manager: no edge from there"
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
        "pm_sys", "pkg_sys", "src_sys", "staged_sys", "cap",
        "consumer_artifact"
      ],
      "lines": {
        "lib_sys": {
          "text": "libtorch_cpu.so",
          "kind": "name",
          "from": "recorded",
          "src": {
            "kind": "run",
            "what": "_out/canary/projects/torch/probe_lib/inspect_lib-fetched-2.1.2_ocaml_binding-fetched-v0.17.0-canary1_binding_source_ocaml-fetched.json",
            "at": "Canary_overview_runs.named_by_inspection"
          }
        },
        "hdr_sys": {
          "text": "torch.h",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's native.headers",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "bridge": {
          "text": "depext: libtorch >= 2.1.0 & < 2.2.0",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's pm_gate",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pm_lang": {
          "text": "opam",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package manager",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "pkg_lang": {
          "text": "torch",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding row's provider (Lang_pkg): its package",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "src_lang": {
          "text": "torch.git",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding source's repo record",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "stub_lang": {
          "text": "libtorch_core_stubs.a",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's coupling",
            "at": "Canary_overview_runs.declared_names"
          }
        },
        "surf_lang": {
          "text": "torch.mli",
          "kind": "name",
          "from": "declared",
          "src": {
            "kind": "code",
            "what": "the binding declaration's surface_path",
            "at": "Canary_overview_runs.declared_names"
          }
        }
      },
      "place_sources": {
        "lib_sys": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "src_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        },
        "mod_lang": {
          "kind": "code",
          "what": "the world's placement of this artifact: its provision and version, from the enumeration",
          "at": "Canary_matrix.provision_choice"
        }
      },
      "gone": [
        "pm_sys", "pkg_sys", "src_sys", "staged_sys", "cap", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "build_lib",
        "build_hdr", "stage", "depext", "conf_probe", "discover"
      ],
      "candidates": [
        "signatures_match_debug_info", "package_contains_declared_files",
        "repack_preserves_api", "repack_complete", "behavior_matches",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "declared_gate_matches_package",
        "gate_bounds_the_library"
      ],
      "counts": { "surf_lang": "19 modules", "lib_sys": "75526 exports" },
      "row": {
        "sort": "torch|e1d373-ocaml|wsl_ubuntu",
        "head": "<tr id=\"row-e1d373-ocaml@wsl_ubuntu\"><th class=\"rt-lab\"><a href=\"#rec=e1d373-ocaml%40wsl_ubuntu\" data-key=\"e1d373-ocaml@wsl_ubuntu\"><b>torch</b> e1d373-ocaml</a> <span class=\"rt-m\">@wsl_ubuntu</span></th>",
        "cells": {
          "fetch_lib|n|pm_sys": "<td class=\"rt-pm rt-off\"></td>",
          "fetch_lib|p|resolve": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|pkg_sys": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_lib|p|realize": "<td class=\"rt-off\"></td>",
          "fetch_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "fetch_lib|c|declared_symbols_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|declared_versions_exported|post|realize_sys": "<td class=\"rt-off\"></td>",
          "fetch_lib|c|soname_matches_declaration|post|realize_sys": "<td class=\"rt-off\"></td>",
          "build_lib|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|p|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_lib|c|declared_symbols_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|declared_versions_exported|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_lib|c|soname_matches_declaration|post|build_lib": "<td class=\"rt-off\"></td>",
          "build_headers|n|src_sys": "<td class=\"rt-art rt-off\"></td>",
          "build_headers|p|build_hdr": "<td class=\"rt-off\"></td>",
          "build_headers|n|hdr_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|p|stage": "<td class=\"rt-off\"></td>",
          "install_lib|n|staged_sys": "<td class=\"rt-art rt-off\"></td>",
          "install_lib|c|staged_interface_preserved|post|stage": "<td class=\"rt-off\"></td>",
          "probe_lib|n|lib_sys": "<td class=\"rt-art\" title=\"libtorch_cpu.so — opam libtorch.2.1.2\">libtorch_cpu.so <span class=\"rt-x\">75526 exports</span></td>",
          "probe_lib|p|probe_lib": "<td class=\"rt-p rt-warm\" title=\"probe_lib: warm\">✓</td>",
          "build_binding|n|src_lang": "<td class=\"rt-art rt-decl\" title=\"torch.git — F\">torch.git</td>",
          "build_binding|n|hdr_sys": "<td class=\"rt-art rt-decl\" title=\"torch.h\">torch.h</td>",
          "build_binding|c|signatures_agree|pre|build_stub": "<td class=\"rt-c rt-dim\" title=\"signatures_agree: not evaluated in any recorded run\">·</td>",
          "build_binding|p|build_stub": "<td class=\"rt-p rt-dim\" title=\"build_stub: inside\">⌂</td>",
          "build_binding|n|stub_lang": "<td class=\"rt-art rt-decl\" title=\"libtorch_core_stubs.a\">libtorch_core_stubs.a</td>",
          "build_binding|n|lib_sys": "<td class=\"rt-art rt-rep\" title=\"libtorch_cpu.so — opam libtorch.2.1.2\">libtorch_cpu.so</td>",
          "build_binding|c|dependencies_provided|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"dependencies_provided: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_symbols_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_symbols_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|required_versions_exported|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"required_versions_exported: not evaluated in any recorded run\">·</td>",
          "build_binding|c|soname_matches_requirement|pre|link_mod": "<td class=\"rt-c rt-dim\" title=\"soname_matches_requirement: not evaluated in any recorded run\">·</td>",
          "build_binding|p|link_mod": "<td class=\"rt-p rt-dim\" title=\"link_mod: inside\">⌂</td>",
          "build_binding|n|mod_lang": "<td class=\"rt-art\" title=\"opam torch.v0.17.0-canary1\">opam torch.v0.17.0-canary1</td>",
          "fetch_binding|n|pm_lang": "<td class=\"rt-pm rt-decl\" title=\"opam\">opam</td>",
          "fetch_binding|p|resolve": "<td class=\"rt-p rt-ok\" title=\"resolve_lang: ran\">✓</td>",
          "fetch_binding|n|pkg_lang": "<td class=\"rt-pkg rt-decl\" title=\"torch\">torch</td>",
          "fetch_binding|p|depends": "<td class=\"rt-p rt-ok\" title=\"depends: ran\">✓</td>",
          "fetch_binding|n|bridge": "<td class=\"rt-pkg rt-decl\" title=\"depext: libtorch &gt;= 2.1.0 &amp; &lt; 2.2.0\">depext: libtorch &gt;= 2.1.0 &amp; &lt; 2.2.0</td>",
          "fetch_binding|p|conf_probe": "<td class=\"rt-p rt-dim\" title=\"conf_probe: absent\">—</td>",
          "fetch_binding|n|cap": "<td class=\"rt-pkg rt-off\"></td>",
          "fetch_binding|c|gate_admits_the_world|pre|conf_probe": "<td class=\"rt-c rt-dim\" title=\"gate_admits_the_world: not evaluated in any recorded run\">·</td>",
          "fetch_binding|p|install": "<td class=\"rt-p rt-ok\" title=\"install_lang, install_surf: ran\">✓</td>",
          "fetch_binding|n|mod_lang": "<td class=\"rt-art rt-rep\" title=\"opam torch.v0.17.0-canary1\"></td>",
          "fetch_binding|n|surf_lang": "<td class=\"rt-art rt-decl\" title=\"torch.mli\">torch.mli <span class=\"rt-x\">19 modules</span></td>",
          "fetch_binding|c|api_names_present|pre|install_surf": "<td class=\"rt-c rt-dim\" title=\"api_names_present: not evaluated in any recorded run\">·</td>",
          "pack_binding|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "pack_binding|p|pack": "<td class=\"rt-off\"></td>",
          "pack_binding|n|pkg_lang": "<td class=\"rt-pkg rt-off\"></td>",
          "probe_binding · run|n|mod_lang": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|n|lib_sys": "<td class=\"rt-art rt-off\"></td>",
          "probe_binding · run|p|run": "<td class=\"rt-off\"></td>",
          "probe_binding · run|n|consumer_artifact": "<td class=\"rt-prog rt-off\"></td>",
          "probe_binding · run_packaged|n|pkg_lang": "<td class=\"rt-pkg rt-rep\" title=\"torch\">torch</td>",
          "probe_binding · run_packaged|p|run_packaged": "<td class=\"rt-p rt-warm\" title=\"run_packaged: warm\">✓</td>",
          "probe_binding · run_packaged|n|consumer_package": "<td class=\"rt-prog\" title=\"\"></td>"
        }
      },
      "outcomes": {},
      "blames": {},
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "opam",
        "cooperation": "unified",
        "character": "unified package universe"
      },
      "placeholders": {
        "resolve_lang": [
          {
            "unseen": "not_yet",
            "text": "opam resolve: the plan opam carried out: each package it installed, rebuilt or removed — a bridge package among them, whose build is when the bridge's check runs; not recorded yet — the install prints one line per package (`∗ installed conf-gmp.5`), or that the package is already installed and nothing was done"
          },
          {
            "unseen": "out_of_reach",
            "text": "opam resolve: why opam's solver chose these versions; out of reach — opam reports the solution it reached, not the search that reached it"
          }
        ],
        "build_stub": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ],
        "link_mod": [
          {
            "unseen": "not_yet",
            "text": "opam build_package: the package's own build inside opam: its configure, where it asks pkg-config for the library, then its compile and link; not recorded yet — opam deletes the build directory when the build succeeds; installing with --keep-build-dir keeps the configure output and the compile commands"
          }
        ]
      }
    }
  ]
});

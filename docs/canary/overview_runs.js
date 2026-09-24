(window.CANARY_RUNS = window.CANARY_RUNS || []).push(
{
  "machine": "wsl_ubuntu",
  "generated": "2026-09-24 02:50",
  "views": [
    {
      "id": "be0605-ocaml",
      "case": "sqlite-ocaml-opam-built",
      "project": "sqlite",
      "scenario": "source-fetched_lib-built-stable_ocaml_binding-fetched-5.1.0_python_binding-fetched",
      "lang": "ocaml",
      "recorded_on": [ "wsl_ubuntu" ],
      "span": [ "2026-09-24 02:49:58.846", "2026-09-24 02:50:04.966" ],
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
        "pm_sys", "pkg_sys", "staged_sys", "cap", "consumer_artifact"
      ],
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
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
      "span": [ "2026-09-24 02:49:58.846", "2026-09-24 02:50:04.991" ],
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
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
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
      "span": [ "2026-09-24 02:50:07.023", "2026-09-24 02:50:13.183" ],
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
        "pm_sys", "pkg_sys", "staged_sys", "cap", "consumer_artifact"
      ],
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
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
      "span": [ "2026-09-24 02:50:07.023", "2026-09-24 02:50:13.206" ],
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
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
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
      "span": [ "2026-09-24 02:50:05.949", "2026-09-24 02:50:06.904" ],
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
      "dim": [ "pm_sys", "pkg_sys", "cap", "consumer_artifact" ],
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
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
      "span": [ "2026-09-24 02:50:05.949", "2026-09-24 02:50:06.930" ],
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
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
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
      "span": [ "2026-09-24 02:50:14.141", "2026-09-24 02:50:15.103" ],
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
      "dim": [ "pm_sys", "pkg_sys", "cap", "consumer_artifact" ],
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
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
      "span": [ "2026-09-24 02:50:14.141", "2026-09-24 02:50:15.132" ],
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
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
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
      "span": [ "2026-09-24 02:49:40.251", "2026-09-24 02:49:47.199" ],
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
        "pm_sys", "pkg_sys", "staged_sys", "cap", "consumer_artifact"
      ],
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
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
      "span": [ "2026-09-24 02:49:40.251", "2026-09-24 02:49:47.227" ],
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
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
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
      "span": [ "2026-09-24 02:49:49.675", "2026-09-24 02:49:55.948" ],
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
        "pm_sys", "pkg_sys", "staged_sys", "cap", "consumer_artifact"
      ],
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
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
      "span": [ "2026-09-24 02:49:49.675", "2026-09-24 02:49:55.973" ],
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
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
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
      "span": [ "2026-09-24 02:49:47.469", "2026-09-24 02:49:48.486" ],
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
      "dim": [ "pm_sys", "pkg_sys", "cap", "consumer_artifact" ],
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
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
      "span": [ "2026-09-24 02:49:47.469", "2026-09-24 02:49:48.513" ],
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
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
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
      "span": [ "2026-09-24 02:49:56.056", "2026-09-24 02:49:57.050" ],
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
      "dim": [ "pm_sys", "pkg_sys", "cap", "consumer_artifact" ],
      "gone": [],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
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
      "span": [ "2026-09-24 02:49:56.056", "2026-09-24 02:49:57.074" ],
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
      "gone": [
        "pm_sys", "pkg_sys", "cap", "bridge", "src_lang", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "depext", "depends",
        "conf_probe", "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "no_build_paths_in_installed_library", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
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
      "span": [ "2026-09-24 02:50:05.075", "2026-09-24 02:50:05.839" ],
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
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
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
      "span": [ "2026-09-24 02:50:05.075", "2026-09-24 02:50:05.865" ],
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
      "gone": [
        "src_sys", "staged_sys", "cap", "bridge", "src_lang", "realize_cap",
        "build_lib", "build_hdr", "stage", "depext", "depends", "conf_probe",
        "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
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
      "span": [ "2026-09-24 02:50:13.286", "2026-09-24 02:50:14.038" ],
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
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
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
      "span": [ "2026-09-24 02:50:13.286", "2026-09-24 02:50:14.060" ],
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
      "gone": [
        "src_sys", "staged_sys", "cap", "bridge", "src_lang", "realize_cap",
        "build_lib", "build_hdr", "stage", "depext", "depends", "conf_probe",
        "discover", "build_stub"
      ],
      "candidates": [
        "exports_accounted_for", "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied"
      ],
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
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
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
        "soname_matches_declaration": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_symbols_exported": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "dependencies_provided": "unevaluated",
        "signatures_agree": "unevaluated",
        "staged_interface_preserved": "unevaluated"
      },
      "badges": {
        "build_lib": "unevaluated",
        "stage": "unevaluated",
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
        "pm_lang": { "label": "opam", "from": "declared" },
        "stub_lang": { "label": "libllvm.a", "from": "declared" },
        "surf_lang": { "label": "llvm.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "cap", "bridge", "pm_lang", "pkg_lang",
        "surf_lang", "consumer_package"
      ],
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
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "compatibility_version_satisfied"
      ],
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
        "soname_matches_declaration": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_symbols_exported": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "dependencies_provided": "unevaluated",
        "signatures_agree": "unevaluated",
        "staged_interface_preserved": "unevaluated"
      },
      "badges": {
        "build_lib": "unevaluated",
        "stage": "unevaluated",
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
        "pm_lang": { "label": "opam", "from": "declared" },
        "stub_lang": { "label": "libllvm.a", "from": "declared" },
        "surf_lang": { "label": "llvm.mli", "from": "declared" }
      },
      "dim": [
        "pm_sys", "pkg_sys", "cap", "bridge", "pm_lang", "pkg_lang",
        "surf_lang", "consumer_package"
      ],
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
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "compatibility_version_satisfied"
      ],
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
        "soname_matches_declaration": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_symbols_exported": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "dependencies_provided": "unevaluated",
        "signatures_agree": "unevaluated"
      },
      "badges": {
        "build_lib": "unevaluated",
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
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "compatibility_version_satisfied"
      ],
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
        "soname_matches_declaration": "unevaluated",
        "declared_versions_exported": "unevaluated",
        "required_symbols_exported": "unevaluated",
        "soname_matches_requirement": "unevaluated",
        "required_versions_exported": "unevaluated",
        "dependencies_provided": "unevaluated"
      },
      "badges": { "build_lib": "unevaluated", "link_mod": "unevaluated" },
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
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "compatibility_version_satisfied"
      ],
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
      "span": [ "2026-09-23 22:11:45.000", "2026-09-23 22:11:55.546" ],
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
        "pm_lang": { "label": "opam", "from": "declared" },
        "pkg_lang": { "label": "zarith-no-conf", "from": "declared" },
        "src_lang": { "label": "Zarith.git", "from": "declared" },
        "surf_lang": { "label": "zarith.mli", "from": "declared" }
      },
      "dim": [
        "src_sys", "staged_sys", "cap", "bridge", "pm_lang", "surf_lang",
        "consumer_package"
      ],
      "gone": [
        "src_sys", "staged_sys", "bridge", "build_lib", "build_hdr", "stage",
        "depext", "depends", "conf_probe"
      ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link"
      ],
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
      "span": [ "2026-09-23 22:11:37.804", "2026-09-23 22:11:44.945" ],
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
      "dim": [ "src_sys", "staged_sys", "consumer_artifact" ],
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
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
        "depends": "absent",
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
        "src_sys", "staged_sys", "cap", "bridge", "consumer_artifact"
      ],
      "gone": [ "staged_sys", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "vendored",
        "cooperation": "undeclared",
        "character": "⚠ undeclared — cannot be classified"
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
        "depends": "absent",
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
        "src_sys", "staged_sys", "cap", "bridge", "consumer_artifact"
      ],
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "apt",
        "cooperation": "undeclared",
        "character": "⚠ undeclared — cannot be classified"
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
        "depends": "absent",
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
        "src_sys", "staged_sys", "cap", "bridge", "consumer_artifact"
      ],
      "gone": [ "staged_sys", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "vendored",
        "cooperation": "undeclared",
        "character": "⚠ undeclared — cannot be classified"
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
        "depends": "absent",
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
        "src_sys", "staged_sys", "cap", "bridge", "consumer_artifact"
      ],
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "apt",
        "cooperation": "undeclared",
        "character": "⚠ undeclared — cannot be classified"
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
        "depends": "absent",
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
        "src_sys", "staged_sys", "cap", "bridge", "consumer_artifact"
      ],
      "gone": [ "staged_sys", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "vendored",
        "cooperation": "undeclared",
        "character": "⚠ undeclared — cannot be classified"
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
        "depends": "absent",
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
        "src_sys", "staged_sys", "cap", "bridge", "consumer_artifact"
      ],
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "apt",
        "cooperation": "undeclared",
        "character": "⚠ undeclared — cannot be classified"
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
        "depends": "absent",
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
        "src_sys", "staged_sys", "cap", "bridge", "consumer_artifact"
      ],
      "gone": [ "staged_sys", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files", "source_is_declared_ref",
        "build_tree_configured_for_source",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "vendored",
        "cooperation": "undeclared",
        "character": "⚠ undeclared — cannot be classified"
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
        "depends": "absent",
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
        "src_sys", "staged_sys", "cap", "bridge", "consumer_artifact"
      ],
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
      "observed": {},
      "chain": {
        "mechanism": "cstubs",
        "lang_side": "opam",
        "native_side": "apt",
        "cooperation": "undeclared",
        "character": "⚠ undeclared — cannot be classified"
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
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
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
      "dim": [ "src_sys", "staged_sys", "cap", "consumer_artifact" ],
      "gone": [ "src_sys", "staged_sys", "build_lib", "build_hdr", "stage" ],
      "candidates": [
        "exports_accounted_for", "signatures_match_debug_info",
        "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "discovery_matches_link",
        "gate_admits_the_world", "declared_gate_matches_package",
        "gate_bounds_the_library", "depext_names_the_provided_package"
      ],
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
      "gone": [
        "pm_sys", "pkg_sys", "src_sys", "staged_sys", "cap", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "build_lib",
        "build_hdr", "stage", "depext", "conf_probe", "discover"
      ],
      "candidates": [
        "signatures_match_debug_info", "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "declared_gate_matches_package",
        "gate_bounds_the_library"
      ],
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
      "gone": [
        "pm_sys", "pkg_sys", "src_sys", "staged_sys", "cap", "resolve_sys",
        "realize_sys", "realize_hdr", "realize_cap", "build_lib",
        "build_hdr", "stage", "depext", "conf_probe", "discover"
      ],
      "candidates": [
        "signatures_match_debug_info", "package_contains_declared_files",
        "correspondence_holds_across_the_binding",
        "no_duplicate_implementation", "interposition_binds_build_target",
        "denotation_stable_across_worlds", "package_resolution_suffices",
        "compatibility_version_satisfied", "declared_gate_matches_package",
        "gate_bounds_the_library"
      ],
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

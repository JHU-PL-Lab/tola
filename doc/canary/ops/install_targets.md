# Install targets — what a project's `cmake --install` actually does

Reference for landing a source-built project. Surveyed 2026-04-16 from Z3
and LLVM; re-verified 2026-08-30. Everything it proposed is now built, so
what survives here is the part that still constrains a spec.

## The work it informed is done

The old TODOs #25 ("model `cmake --install` as an action slot") and #40
("replace the `cp` fake") are both shipped. `install_lib` is a real
install in both projects:

| project | template | fires when | prefix |
| --- | --- | --- | --- |
| z3 | `Cmake_install { assert_staged }` | `ar_needs = Some Installed` | `<project>-all/install-<ref>` (per ref) |
| llvm | `Cmake_install_component { component = "LLVM" }` | default rule (`Built`) | `<build>/../install` |

The `install_strategy` union this doc originally proposed — one strategy
per project — was **not** adopted and should not be revived. Install is a
per-**action-row** template (`Canary_action_templates.action_template`),
which is what lets z3 gate staging on the `Installed` provision while
llvm's fires in every Built world. One project can need both shapes; a
per-project union cannot express that.

Prefix safety is enforced in `cmake_install_cmd`: a prefix is a required
labelled argument, and the emitted shell refuses an empty expansion, so
no caller can fall back to `CMAKE_INSTALL_PREFIX = /usr/local`.

## Three discovery patterns

| Pattern | Representative | Discovery tool | OCaml install | Rpath |
| --- | --- | --- | --- | --- |
| **pkg-config** | Z3 | `z3.pc` + `Z3Config.cmake` | see below | build-time `$ORIGIN` |
| **llvm-config** | LLVM | `llvm-config` binary | cmake `install()` | `$CAMLORIGIN/../..` (relocatable) |
| **cmake config only** | many C++ libs | `*Config.cmake` only | n/a | standard cmake rpath |

## Z3 — the OCaml install is REF-DEPENDENT

This doc used to state flatly that `src/api/ml/CMakeLists.txt` has no
`install()` calls, so the OCaml package must be installed separately with
`ocamlfind`. That is no longer a fact about Z3; it is an axis, and it is
the axis canary tests:

| ref | `install()` in `src/api/ml/` | canary |
| --- | --- | --- |
| official `latest` (post-#10549, `93c609d`) | present | `assert_staged` passes |
| official `pre-10549` | absent | `assert_staged` fails → declared xfail |
| `arbipher` fork | absent (verified at `1d8c50eb`) | `official = false`, so unasserted |

`assert_staged = ["lib/ocaml/z3/META"; "lib/ocaml/z3/z3ml.cmxa"]` is what
encodes it. The two open questions this raises — the fork cannot serve a
staged consumer, and `assert_staged` lives outside the world vocabulary —
are tracked in [`../project/issues.md`](../project/issues.md).

## LLVM — the install layout *is* the rpath

`llvm.cmxa` carries `-L$CAMLORIGIN/../.. -Wl,-rpath,$CAMLORIGIN/../..`,
where `$CAMLORIGIN` is the directory of the `.cmxa` at link time. So the
rpath is correct only when the install layout is `$PREFIX/lib/ocaml/llvm/`
for the cmxa and `$PREFIX/lib/` for `libLLVM.so` — which the build tree
and a normal `cmake --install` both satisfy, and opam's flat `lib/llvm/`
does not. `LLVM_OCAML_INSTALL_PATH` overrides the destination if needed.

`llvm.dev-shared` bypasses `cmake --install` and copies into the flat
layout, so it must compensate in META — see
[`llvm_build.md`](llvm_build.md).

## Failure modes at the install boundary

1. **Wrong prefix** — cmake installs to `/usr/local/` while the conf-\*
   package probes `/usr/lib/llvm-N/`.
2. **Rpath baked to the build tree** — `$ORIGIN` / `$CAMLORIGIN` correct
   at build, wrong after install if the layout changes.
3. **The binding is not installed by the same command as the lib** — see
   the Z3 table above; whether it is depends on the ref.
4. **`llvm-config` not on PATH** — conf-llvm probes fail quietly and fall
   back to the wrong version. Handled by `llvm_config_cmd ~locator_hint
   ~macos_pkg`.
5. **META `directory` field** — if the installed META says
   `directory = "subdir"`, ocamlfind expects the archives there; it must
   match the actual layout.

(2) and (5) are also CLAUDE.md gotchas — they have bitten more than once.

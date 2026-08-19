# Handoff — the provider-exclusive-rows arcs (2026-08-18)

Session wrap: three arcs, two landed, one queued. This file is the
new agent's entry point for project progress + debugging.

## The arcs and their commits

| commit | arc | status |
| --- | --- | --- |
| `9083d3b` | installed-consumer experiment: `consumer_lib = Build_tree \| Installed` realization POLICY + `--installed` (z3's probe reads the staged prefix; the pre-10549 staged-probe xfail declared) | ✅ landed |
| `b83bbfa` | staged-parity principle + cross-agent brief (`doc/canary/design/staged_parity.md`) | ✅ docs |
| `f28304c` | matrix rows group by ref (declared repo order) → c lib → bindings | ✅ landed |
| `d3eda2f` | matrix row index: `#N` ordinal + stable 6-hex code (display-only, never in cache keys) | ✅ landed |
| `bf5e892` | **the enumeration arc**: `provision` += `Installed` + built-family semantics + `ar_needs`; **the sqlite arc**: 5 worlds, provider-exclusive rows | ✅ landed |
| `5ef2eaa` | `provider_rows_pin` becomes a GENERAL factory (derived assertions, not hand-listed) | ✅ landed |

## 1. The enumeration arc — GENERAL machinery (done, `bf5e892`)

Any project can now declare an Installed lib universe; the framework
does the rest:

- **base** (`canary_store.ml`): `provision = ... | Installed` (the
  dormant `artifact_status.Installed` renamed `Installed_state` —
  zero consumers). `string_of_provision "installed"`.
- **enumerate** (`canary_enumerate.ml`): the built FAMILY — an
  Installed world's chain builds like Built: `assignment_ok`'s
  source-channel coupling, the walk lockstep (`equal_provision pv
  Built || Installed`), `pattern_of_assignment`, the chain-match,
  `rp_deploy`, `built_from_of_assignment`; the inverse read
  (`provision_of_actions`: Install_lib alone ⇒ Installed). The
  shadow prebuilt helper deliberately does NOT treat Installed as
  prebuilt (no shadowing).
- **templates** (`canary_action_templates.ml`): `action_row.ar_needs :
  provision option` — the project's per-row EXACT firing override
  (consulted FIRST in `row_applies`); the DEFAULT build-step gates
  accept the built family (the shared build fires in both worlds)
  while the probe-location gates stay exact (consumer exclusivity).
  All row literals in sqlite/z3/llvm carry `ar_needs` (mechanical).
- **identity/display**: `scenario_dir_of` `*-installed-<chan>`;
  `prov_short` "I"; matrix cells `lib I:d`; the lib row-key =
  (channel, prov_rank, id) with Fetched LAST — the "repo × 2 + 1
  fetched" row order.
- **registry arms**: `firing_default` (Installed groups with Built),
  `providing_action_of` (Installed → Install_lib),
  `producing_action_of_node`, `edge_label_of_node` ("install" verb).

## 2. The sqlite arc — PROJECT DATA (done, `bf5e892` + `5ef2eaa`)

sqlite instantiates the general model:

- universe: `(Fetched [Stable]); (Built [Stable;Dev]); (Installed
  [Stable;Dev])` → 5 worlds.
- rows: `Install_lib` Raw (copy-out into `<ws>/install/lib`,
  `ar_needs = Some Installed`) + a `Staged_lib` Probe_lib row
  (`ar_needs = Some Installed`); `realize` dispatches the OCaml
  probe env on the lib provision (Built → `<ws>/lib`, Installed →
  `<ws>/install/lib`).
- pins: `provider_rows_pin ~prefix:"sqlite" ...` (the general
  factory) + `sqlite.staged_probe_paths` (the realization-specific
  probe-env check the factory can't derive).

Live-verified: 5/5 PASS; the Installed worlds run fetch → build →
install → staged probe; the Built worlds never run install; matrix
rows [B 3.45.1, I 3.45.1, B 3.46.1, I 3.46.1, F apt].

## 3. The z3 arc — QUEUED (the full bill, ready to execute)

Recorded in `doc/canary/project/status_project.md`. The migration,
file by file (all in `canary_project_z3.ml` unless noted):

1. **Universe data**: lib row gains `(Installed, [Dev])`; the source
   row gains `~follows:a_lib` — the one-line phantom-axis fix (the
   follows post-filter channel-locks the source to the lib: the 4
   identical fetched worlds collapse to 1 (source = 4.15.2), the dev
   chains keep latest/arbipher/pre-10549).
2. **Row data**: `Install_lib` row `ar_needs: None → Some Installed`;
   the `Staged_lib` probe row `→ Some Installed`; the build-tree
   probe row stays (excluded from Installed automatically). The
   probe_binding OCaml Raw cmd's two branches stay byte-identical —
   only the dispatch re-keys from `consumer_lib` to
   `provision_of a a_lib`.
3. **Expectation re-key**: the pre-10549 xfails (install +
   `STAGED PACKAGE MISSING`) gate on lib provision = Installed.
4. **Retirement**: `consumer_lib` + `run_config.consumer_lib` +
   `--installed` + the runner threading deleted (or `--installed`
   becomes a provision-subset filter — the `Subset` machinery
   exists). The `z3.installed_probe_consumes_prefix` pin is
   replaced by `provider_rows_pin ~prefix:"z3" ...` + a
   realization pin like sqlite's.
5. **Pin updates**: `matrix.row_order`'s z3 sequence becomes
   [4.15.2×F; latest×B,I; arbipher×B,I; pre-10549×B,I];
   `integration.smoke`'s z3 count STAYS 7 (composition changes,
   count doesn't); the matrix-shape pin's cells gain `lib I:d`.

**Coincidence to remember**: the scenario counts don't change
(7 → 7; `--refs latest,pre-10549` 4 → 4) — only the composition.

## 4. Debugging + progress guide

- Build/test: `dune build`; `make canary-test` (project-test +
  artifact-test + pm-test — 93 + 109 + 14 at handoff) after every
  edit touching `src/canary/`; `make canary-post-check` before
  committing/ending (heavier).
- The pin registry is the progress meter: `dune exec
  src/bin/canary_main.exe -- project-test` — one `[PASS]` line per
  invariant. New behavior = new pin, per the project convention.
- Live runs: `action sqlite` (5 worlds); `action z3 --refs
  latest,pre-10549` (default) and `--installed` (both must stay
  byte-identical until the migration); `action zarith` warm.
- `canary result` = the pure-read matrix (rows carry `#N` + a
  stable code; hover the web `#` column for the code).
- Gotchas that bit this arc: the ratchet (`harness.tool_routing_ratchet`
  counts shell-verb mentions in `src/canary/project` comments too —
  "cmake " in a comment fails it); stale-LSP false positives after
  cross-module edits (trust `dune build`); `open Base` int-only `=`;
  the warm cache fingerprints realized cmds (policy/realization
  changes re-run automatically); Edit-tool-only for OCaml source.
- Co-existence: the M2/m3 agent is PAUSED (2026-08-17); two
  compile-facing signatures for any in-flight landing:
  `pr_runner_spec` accepts `?(consumer_lib = Build_tree)` (until the
  retirement) and action rows carry `ar_needs`.
- Future items (status_project.md): the multi-provider axis (fetch/
  build against several libs — the PM-count fetched row is its
  seed), the staged-parity checker (4 checks), per-world install
  prefixes (z3's shared `z3-all/install` accumulation finding), the
  `--cold` flag, the selection-config unification.

## 5. The handoff prompt (paste into the new session)

```text
You are taking over the tola canary work (branch ds-workflow) from a
completed session. Start by reading
doc/canary/worklog/handoff_2026_08_18_provider_rows.md — it is the
state of three arcs: (1) the enumeration arc (Installed provision +
built-family semantics + ar_needs — GENERAL machinery, landed
bf5e892), (2) the sqlite arc (provider-exclusive rows, 5 worlds,
landed), (3) the z3 arc (QUEUED — the full migration bill is in the
file's section 3 and in doc/canary/project/status_project.md).

Your first task: the z3 migration per the bill. Verify as you go:
make canary-test after each tier; the z3 runs (action z3 --refs
latest,pre-10549, both with and without --installed) must keep their
verdicts until the migration flips the shape; then update the pins
the file lists and re-verify live. Project conventions: bash =
make/dune only; Edit tool only for OCaml source; every increment
ships a pin; commit per completed tier with the Co-Authored-By
trailer. If anything in the handoff contradicts the code, trust the
code and note the discrepancy.
```

# Wrapper packages, the conf-free direction, and the Publish generalization

> 2026-08-17. CANARY-SIDE design: our wrapper/conf-free packages in the
> local opam repo, the fork layering, the store-mutation consequence,
> and the zarith matrix + shadow preference. (The opam-side survey of
> the `conf-*` mechanism itself lives in
> [`../surveys/conf_mechanism.md`](../surveys/conf_mechanism.md).)
>
> Moved here from `project/` 2026-08-21: design principle, not a
> per-project record. Per-project consequences live in
> [`../project/issues.md`](../project/issues.md).

## 1. The fork layering — a functional fix vs a conf-bypass

We have a forked zarith (`zarith-my-fork`) carrying a functional fix;
should the conf-bypass be a separate branch or commit in the fork?
**Neither — it belongs in a different layer entirely.**

- **The functional fix lives in the FORK** (a branch off upstream,
  PR-ready, no packaging noise). Canary describes it with the repo
  record (`label = Some "my-fork"`, `official = false`, `ref_`,
  remote) as an entry in the `Repo_axes` family.
- **The conf-bypass is PACKAGING, not source** — an opam-file-level
  change ("build this tree without consulting `conf-gmp`"). It is
  version-agnostic: the SAME bypass applies to stable, master, and the
  fork alike. Putting it in the fork would (a) duplicate it per ref,
  (b) pollute the upstream-reportable fix branch with workflow
  concerns upstream would never merge.
- **Canary's description of the bypass**: the `pr_wrapper_pkgs` field +
  the local opam repo (`canary/templates/opam-local-repo/`) — the
  dev-mode wrapper packages (`z3.dev`, `llvm.dev-shared`) that
  override the dep graph. `zarith-no-conf` is the same shape: a local
  package whose `build:` runs `./configure && make` over the
  scenario's checkout and whose `depends:` omits `conf-gmp`. The fork
  record and the wrapper declaration stay separate spec fields, so
  canary can enumerate "fork source × conf-free packaging" freely.

## 2. The store-mutation consequence (the reinstall)

opam's store is global and findlib-keyed: `zarith` and `zarith-no-conf`
both install the findlib package `zarith`, so only one can own the
namespace at a time — installing one clobbers the other. Options:

- **Distinct findlib name** (`zarith_no_conf`) — both coexist, but the
  probe compiles against a DIFFERENT name than the real-world consumer
  uses (weakens the realism of the check).
- **Same findlib name, pin-switched scenarios** — the scenario that
  needs the fork installs `zarith-no-conf`, the stable scenario
  re-pins `zarith.1.14`; each step's `pin_check_post` verifies the
  store provably holds the right package before probing. This is
  EXACTLY the z3 stable/dev dance (opam pin 4.16.0 ↔ publish z3.dev),
  and the machinery exists: pin-checked fetch, world assertions,
  "order is a performance contract, not a correctness one"
  (algorithm_explainer.md §10).

The same-name variant is the right default — realism beats coexistence.

## 3. The zarith matrix and the shadow preference

The combination space: GMP has no system dev package (`libgmp-dev`
ships only 6.3.0) and no nightly; the dev GMP is gmplib.org's hg repo
(`Hg`/`Tar` remotes covered). Since conf-gmp constrains nothing, a
future GMP release flows into the system path automatically — the
ideal matrix:

```
                 gmp 6.3.0 (system)   gmp master (official repo)
zarith 1.14      current cell          old-binding × new-lib (deploy)
zarith master    new-binding × old-lib (forward)   new × new
```

**Prebuilt-shadows-source** (user, 2026-08-17 — the rule that came out
of the GMP build session): building an external C lib is NOT always
easy (GMP's hg tree: partial bootstrap, missing libtool.m4, VPATH aux
traps, empty `$NM`). Rules:
- If a latest PREBUILT exists (including a nightly/dev artifact — e.g.
  a CI-built archive), USE it; it shadows the source.
- If not, only the system PM's latest stable. NO source-built lib
  column by default.
- The source-built path is a SEPARATE AUDIT PASS, not automatic: it
  runs only when we have decided to BLAME the lib (a fix to prepare or
  confirm). The failure-triggered fallback never fires on its own.
- The binding-language side builds are cheap and stay in the matrix —
  that's where the fixes live.

**Current zarith shape** (verified 3/3 PASS): the lib row is
Fetched-only; the matrix collapses to `{zarith 1.14, master} × {gmp
6.3.0}` = 3 scenarios — the current cell, the master-source world, and
the FORWARD cell (master binding built from the worktree copy, probed
against the system lib — the designed mismatch probe). The
`gmp_source_master` repo record stays DECLARED but unwired (the ssl
unwired-dev precedent); the hg checkout lives in `contrib/gmp-all/`.

The general **shadow mechanism** — LANDED (2026-08-17, active plan 3)
as an enumeration-POLICY item, no spec changes (per the user's
correction: the spec stays simple and clean; whether/how the shadowing
happens is a config item used in the enumeration part):

- `Canary_enumerate.shadow_policy = Shadow_prebuilt | Materialize_source`
  on the enumeration config (default `Shadow_prebuilt`). When a spec
  declares BOTH a prebuilt column (Fetched/Vendored) and a Built column
  for the same artifact, the shadow RESOLVES them into one scenario —
  the prebuilt wins, the Built placement is dropped.
- The firing condition is IDENTITY-BEARING same-version: the Built
  side's version id is SOURCE-PRIMARY (a Built artifact's version IS
  its source's — the source placement's pin id), both ids must be
  non-empty and EQUAL, channels must match, and the rest of the
  assignment must be identical. An ambient (unpinned) prebuilt never
  shadows — the same-version belief needs the version to be known on
  both sides (sqlite's built amalgamations are NOT the system's).
- `Materialize_source` keeps both worlds — the SEPARATE AUDIT PASS
  (blame-driven): `run_policy` gains the `Audit_lib` rung (`--audit-lib`,
  full + Materialize_source); the batch never picks it. Fetch + build +
  re-probe + blame.
- Pinned by `enumerate.shadow_policy_drops_same_cell_built` (same cell
  drops under Shadow_prebuilt, survives under Materialize_source;
  different cells — the z3 shape — never shadow) and
  `shadow.policy_ladder` (Full/Thin shadow, Audit_lib materializes).
- zarith/z3/llvm today: unchanged (zarith's lib row is Fetched-only;
  z3/llvm's Fetched@Stable + Built@Dev are different cells). The
  machinery is ready for the day a blame-driven spec change adds a
  Built column.

### 3.1 Decision brief — the Audit_lib rung (for the checking/audit agent)

> 2026-08-17. Handed to the agent who owns the checking/audit topic
> (the contract-registry arc, the verdict-matrix/`--cold` ideas) to
> decide: keep, revert, or re-key the audit rung. The shadow policy
> itself (§3 above) is NOT in question — only the audit pass machinery
> built on top of it.

**Background.** The prebuilt-shadows-source rule (user, 2026-08-17):
for the same (channel, version) cell, a prebuilt lib (official or
vendored) shadows a source-built one — building an external C lib
(GMP) proved unreliable enough that the source-built path is a
SEPARATE, blame-driven audit pass, never automatic. The rule landed
(commit `0c6b64c`, active plan 3) as an enumeration-policy item:
`shadow_policy = Shadow_prebuilt | Materialize_source`
(`src/canary/action/canary_enumerate.ml`, `shadow_filter` — a
POST-PROCESSING pass after the product/walk, not wired into the
enumeration core), with an identity-bearing same-version firing
condition. To make the silent drop overridable, the plan added the
audit rung:

- `run_policy` gains `Audit_lib` (`canary_project_run.ml:199`),
  `enumeration_policy_of` maps it to full + `Materialize_source`
  (`canary_project_run.ml:227`), `audit_policy ()` is the literal
  (`canary_project_run.ml:172`).
- CLI `--audit-lib` on BOTH `action` (`canary_main.ml:117,139-153`)
  and `spec` (dry-run view, `canary_main.ml:216,241-256`);
  `Canary_batch.run ~force_audit` (`canary_batch.ml:65,70`) — the
  batch itself never picks it.
- Pins: `enumerate.shadow_policy_drops_same_cell_built`
  (`canary_project_test.ml:565`) + `shadow.policy_ladder`
  (`canary_projects_test.ml:807`).

**Facts.** Inert today — no project declares a Built column sharing a
prebuilt cell (zarith's lib is Fetched-only; z3/llvm's Fetched@Stable
+ Built@Dev are different cells; sqlite/tiny carry no pins). So the
rung costs only surface: a run-policy variant, two CLI flags, a batch
param, two pins, doc lines.

**The question.** "Auditing/checking" is the OTHER topic (the
contract-registry arc; the pending `--cold`/verdict-matrix
enhancement), and the user reads the rung as "a small hack" — the
shadow's override may belong there, or may not be needed at all.
Options:

1. **Keep** — tested, inert; the override is ready for blame day.
2. **Revert the rung** (user's lean): the shadow always wins
   (`Shadow_prebuilt` fixed); materializing the Built column is then a
   SPEC EDIT (declare the column = the switch — zarith's state today
   is exactly "the source is just disabled"). Revert scope: the
   `Audit_lib` variant + `audit_policy ()` + the
   `enumeration_policy_of` case (`canary_project_run.ml`), the two
   CLI flags (`canary_main.ml`), `~force_audit`
   (`canary_batch.ml`), the `shadow.policy_ladder` pin, the doc
   lines. KEEP regardless: the `shadow` config field, `shadow_filter`,
   `drops_same_cell_built`, the docs §3.
3. **Re-key as per-project config** (registry-level): the shadowing
   belief is a per-project judgment ("a lib like gmp working is kind
   of random"), not a universal law — a per-project flag replaces the
   global policy. Cheap: `shadow_filter` is already a post-processing
   filter keyed by the config.

**The bigger frame** (user, 2026-08-17): shadowing (gmp) and the
source-building bypass (z3's Heavy→Thin tier) are the SAME topic —
one general rule for the enumeration's special cases, revisited "a bit
later" (../project/status_project.md design-stage). Don't over-invest in the
rung's current shape; if it survives, it's a placeholder for that
revisit.

## 4. The Publish generalization — LANDED (2026-08-17)

z3/llvm carried legacy-but-working Publish steps; the generalization is
now landed for the ocaml/opam-binding pattern (active plan 2), and tiny
can ride the same primitive. Current
state: hand-written opam files per wrapper package in
`canary/templates/opam-local-repo/packages/{z3,llvm,zarith}/` —
z3.dev uses an `.in.tpl` with `%%Z3_CMAKE_BUILD_FLAGS%%` substitution
(rendered by `Canary_project_z3.render_opam_in`); llvm.dev-shared and
zarith-no-conf are static.

Open question: a GENERAL opam-template (one skeleton parameterized per
project) vs per-project template files. The packages differ only in
the build body (z3: cmake+ninja; llvm: cmake; zarith: configure+make);
the skeleton is common: opam metadata, the `CANARY_*_SRC` url, the
build/install/remove slots, the conf-free depends, the same-findlib
conflict. LANDED shape: `Canary_opam_template` (tool/) renders the skeleton
from a per-project `wrapper_decl` (the renderer pin asserts byte-
equality with the committed file); the committed file is `opam.in`
(the `.in` convention — opam indexes only `opam`; the pack primitive
substs it with the `OPAMVAR_`-prefixed source var, the dir convention
`packages/<name>/<name>.<version>/`); `Canary_pm_opam.pack_wrapper_cmd`
self-registers the repo + drops the conflicts + installs + writes the
marker; the pattern's Publish fires in the bind_built scenarios with
the pin-checked postcondition, and the Fetched-binding probe carries
the world check (self-heal: reinstall the stock package) with its
check_post re-verifying the store on warm skips (the skip-gate fix in
the playbook's findings). Verified: 3/3 PASS, the dance ends with the
stock package restored.

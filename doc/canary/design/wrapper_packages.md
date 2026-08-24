# Wrapper packages, the conf-free direction, and the Publish generalization

**Kind: rationale.** The wrapper packages, the shadow mechanism and the
Publish generalization all landed. §3.1 used to hold an open decision
brief about the `Audit_lib` rung; that decision was MADE and executed on
2026-08-19 (the rung was removed), so the brief is gone and §3 records
the outcome.

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
  (enumeration/stage4_order.md §2).

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
The general **shadow mechanism** — LANDED (2026-08-17), then SIMPLIFIED
(2026-08-19, user: *"I think we remove this feature"*). It is an
enumeration filter, not a policy, and there is no way to turn it off:

- `Canary_enumerate.shadow_filter` runs as a POST-PROCESSING pass after
  the product/walk. When a spec declares BOTH a prebuilt column
  (Fetched/Vendored) and a Built column for the same artifact, the
  shadow RESOLVES them into one scenario — the prebuilt wins, the Built
  placement is dropped.
- The firing condition is IDENTITY-BEARING same-version: the Built
  side's version id is SOURCE-PRIMARY (a Built artifact's version IS
  its source's — the source placement's pin id), both ids must be
  non-empty and EQUAL, channels must match, and the rest of the
  assignment must be identical. An ambient (unpinned) prebuilt never
  shadows — the same-version belief needs the version to be known on
  both sides (sqlite's built amalgamations are NOT the system's).
- **What was removed on 2026-08-19**, and why this section reads as it
  does: the mechanism first landed as a two-valued policy
  (`shadow_policy = Shadow_prebuilt | Materialize_source`) with an
  `Audit_lib` run-policy rung and an `--audit-lib` CLI flag on `action`
  and `spec`, so a blame-driven pass could unhide the Built column.
  Nothing ever used it, and a project that wants its source-built lib
  visible should declare it as a **distinct version** rather than ask a
  run flag to unhide it. The variant, the rung, the flags and
  `~force_audit` are all gone; `run_policy` is `Full | Thin`.
- Pinned by `enumerate.shadow_policy_drops_same_cell_built` (the same
  cell drops; different cells — the z3 shape — never shadow) and
  `shadow.policy_ladder` (which now asserts the Full/Thin ladder only).
- zarith/z3/llvm today: unchanged (zarith's lib row is Fetched-only;
  z3/llvm's Fetched@Stable + Built@Dev are different cells). The
  machinery is ready for the day a blame-driven spec change adds a
  Built column.

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

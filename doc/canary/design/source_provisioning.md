# Getting the source — what a CI run pays for, and why not submodules

**Kind: proposal.** **Landed when** a world realizes no `fetch_source`
step that nothing in that world depends on — `canary emit cairo --stage
realize` shows no `fetch_source`, and cairo's CI job stops cloning.

> 2026-08-27, user: *"since canary is testing for more projects and each
> project need to be cloned during the GH CI steps, shall we clone the
> repo in each project_spec and treat them as github submodule instead of
> a CI action?"* — and, on the follow-up: *"it's worth a doc to describe
> the issue and discuss the plan, since GH CI is a quite good (free) CI
> to run our experiment."*
>
> The submodule question has an answer (§2, no). The cost behind it is
> real and has a sharper cause than transport (§3), and §4 is the fork
> still open.

## 1. What happens today

A `source_repo` declares a remote and a ref; `worktree_ensure_cmd` emits
clone-if-missing → `fetch origin <ref>` → `worktree add` → `checkout`,
into `<contrib_root>/<project>-all/<repo>`. Locally that root is the
shared contrib tree and stays warm across runs. On CI the machine root is
`$GITHUB_WORKSPACE`, so every job starts from nothing.

## 2. Not submodules

Four reasons, in decreasing order of how much they would hurt.

1. **It deletes an action canary exists to test.** `fetch_source` is in
   the action catalogue with a `check_post`, an expectation and edges in
   the dependency graph. Canary's subject is provisioning — `Fetched |
   Built | Installed | Vendored` — so obtaining a source is *a step that
   can fail*, not a precondition. A submodule makes it ambient.
2. **One submodule pins one SHA; canary needs several refs per repo.** z3
   tracks three (`latest` / `arbipher` / `pre-10549`) and `--refs
   latest,pre-10549` is a regression experiment across two of them.
   Today: one repo, one `git worktree` per ref, objects shared. As
   submodules: three submodules of one upstream, or a pointer mutated per
   scenario.
3. **CI gets slower, not faster.** `actions/checkout` resolves submodules
   at job start, before it knows which scenario runs. The sqlite job needs
   no git source at all (its source is a curl'd amalgamation zip) yet
   would pay for llvm-project. Selective init is a per-job step again —
   what we have now, but implicit.
4. **It reverses a standing decision.** `~/.claude/CLAUDE.md`:
   *"Third-party repos used by more than one project are not vendored
   per-project (no submodules, no copies). They live under a shared
   contrib tree."* The reason given there — one source tree, one warm
   build cache — is why the memory also says never `rm -rf contrib/*`.

## 3. The real cost is a step nothing needs, at full history

Measured, cairo's all-`Fetched` world:

```
fetch_source         deps=[]                              <- no dependents
fetch_lib            deps=[]
probe_binding_ocaml  deps=[fetch_binding_ocaml,fetch_lib]
probe_lib            deps=[fetch_lib]
```

We clone cairo's entire history for a step **whose output no other step
reads**. Contrast sqlite's Built world, where `build_lib
deps=[fetch_source]` and the tree is genuinely consumed.

So the expense is not *how* the source arrives. It is that a world
realizes a source it never uses, and that the fetch was a full clone.

### 3a. Clone shape — measured on cairo (2026-08-27)

| shape | `.git` | clone | second ref via `worktree add` |
| --- | --- | --- | --- |
| full (what we did) | 106M | 9.8s | works |
| `--filter=blob:none` | 44M | 8.3s | **works** — +1.1s, +4M |
| `--depth 1` | 34M | 4.5s | **fails** |

`--depth 1` is the cheapest and the one we cannot use:

```console
$ git fetch --depth 1 origin 1.18.0     # ok
$ git worktree add -f <wt> 1.18.0
fatal: invalid reference: 1.18.0
```

A shallow fetch does not create the local ref, so worktree-per-ref — the
model z3's regression pair depends on — breaks. **Our constraint is many
refs, not one commit; depth optimises for the opposite case.** Partial
clone withholds blobs, not history, so it serves any ref on demand.

**Landed 2026-08-27**: all three canary clone sites now pass
`--filter=blob:none` (`canary_artifact_source.ml` ×2,
`canary_action_templates.ml` ×1). Emitted command text changed, so every
source step re-runs once.

Still worth knowing: the checked-out tree is 71M of cairo's 177M and is
identical under all three shapes. Clone shape cannot fix a checkout we
did not need.

## 4. The open fork — how to stop realizing a step nothing needs

Two shapes, and they differ in ambition rather than in outcome.

**Quick.** Prune at the end of realize: drop a step that is neither a
terminal check nor transitively required by one. One filter in
`derive_steps`, no new concepts.

**Heavy.** Derive steps by demand instead of by catalogue walk: start
from the checks a world declares and close backwards over the dependency
relation. `close_deps` / `execution_plan` in `canary_action.ml` already
compute a closure like this for the node-graph view — the one that
[drifted from `step.deps`](../../../CLAUDE.md) and is why the diagram's
connectivity check is muted. So the heavy fix is also the merge that
status §A already wants: **one dependency relation, used both to draw and
to derive.**

**Recommendation: write the quick fix as the demand rule.** Prune by
backward reachability from the terminal checks — the same semantics the
heavy fix would give — so the heavy version becomes "move this rule from
a post-filter into the derivation", with a pin already guarding the
behaviour. Doing the quick fix as an ad-hoc special case for
`fetch_source` would be the version that has to be undone.

### 4a. What pruning costs, and the choice inside it

Cloning cairo proves something true: *cairo's declared source is
obtainable at the declared ref*. Prune it and a Pattern-A project — whose
worlds are all `Fetched` — never exercises its source row at all, while
`spec-check` still reports the row as declared. That is a real coverage
loss, not a free win.

| option | keeps the claim | cost per world |
| --- | --- | --- |
| **a1** prune unconditionally | no | 0 |
| **a2** prune on CI only | on one machine | 0 on CI — but CI stops being the same steps as local, which is the property the CI backend was just rebuilt to have |
| **a3** prune the clone, keep a remote check (`git ls-remote --exit-code <url> <ref>`) | yes | **1.1s, 0 bytes** (measured) |

a3 is the interesting one: it separates *the tree is here* from *the
source is obtainable*, which are two different claims that a full clone
happens to answer at once. It needs a cheap action (a reachability probe,
not a fetch) — small, but it IS a new action in the catalogue, so it
wants the user's call.

**Recommendation: a3 for worlds with no dependents, a1 if we decide the
obtainability claim belongs to `spec-check` rather than to a run.**

## 5. Not in scope here, but adjacent

- **Cache the contrib tree on CI** keyed on (repo, ref). The composite
  action `.github/actions/canary-setup` is the natural home; the z3
  fork's canary infra caches ccache the same way. Worth doing after §4 —
  §4 removes the fetch entirely for the worlds that pay most.
- **`git ls-remote` as a spec-check probe.** `spec-check --probe-pm`
  (`platform.md` §7 item 1) wants to validate declared package NAMES;
  validating a declared source ref is the same shape and the same one
  second.

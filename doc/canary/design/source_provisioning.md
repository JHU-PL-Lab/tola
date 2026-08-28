# Getting the source — what a CI run pays for, and why not submodules

**Kind: proposal.** **Landed when** a world realizes no step that nothing
in it depends on — the rule uniform over actions, not special-cased to
`fetch_source` — so `canary emit cairo --stage realize` shows no
`fetch_source` and cairo's CI job stops cloning. The declared source row
stays declared, and whether its ref resolves becomes a `spec-check`
probe.

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

| shape                | `.git` | clone | second ref via `worktree add` |
| -------------------- | ------ | ----- | ----------------------------- |
| full (what we did)   | 106M   | 9.8s  | works                         |
| `--filter=blob:none` | 44M    | 8.3s  | **works** — +1.1s, +4M        |
| `--depth 1`          | 34M    | 4.5s  | **fails**                     |

`--depth 1` is the cheapest, and we still do not use it — but **not for
the reason first given here.** The original text claimed shallow clones
cannot serve a second ref, on the strength of one failed command:

```console
$ git fetch --depth 1 origin 1.18.0     # ok
$ git worktree add -f <wt> 1.18.0
fatal: invalid reference: 1.18.0
```

That is a REFSPEC failure, not a shallowness one — a bare `git fetch
origin <ref>` updates `FETCH_HEAD` without creating a local ref. Spell
the refspec and shallow handles multiple refs fine (audit §3, verified
2026-08-27):

```console
$ git fetch --depth 1 origin +refs/tags/1.18.0:refs/tags/1.18.0
$ git worktree add -f <wt> 1.18.0       # works; .git 38M
```

**The real objection is history, and the same test shows it:** inside
that worktree `git log --oneline | wc -l` is **1**. A shallow tree
answers questions about history wrongly rather than refusing them, and
our source-BUILT projects are exactly the ones that ask — z3 and LLVM
derive version information from git metadata, and CLAUDE.md already
records a cmake-vs-git failure in the z3 checkout. Partial clone
withholds blobs, not history, so every such query still gets the true
answer.

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

**Landed 2026-08-28, and NOT as the backward-reachability closure this
section first recommended.** That version — classify every step as an
"obligation", close over `step.deps` both ways — was built and then
replaced, for two reasons the user's question surfaced:

- *"Obligation" was a category invented to make the closure terminate*,
  not vocabulary this model has. It needed `Publish` bolted on by hand
  the moment it met zarith's pack step.
- **It pruned on `step.deps`** — the relation we already know has drifted
  from the node graph, and the reason the diagram check is muted. A
  missing edge there silently becomes a deleted step.

What shipped is one question per fetch, asked of the TYPED catalogue:

> **drop a `Fetch k` when no step in this world consumes `k`.**

`consumes_of_action` / `produces_of_action` are declared and pinned
(`consumes_produces.*` in `canary project-test`), so the rule rests on
the relation that is tested rather than the one that drifted. It touches
only fetches, so it cannot reach a pack, a build or an install, and the
`Publish` exemption disappeared with it.

The heavy fix (demand-driven derivation, one dependency relation used
both to draw and to derive) is still the right end state and still what
status §A wants — but it is now an independent piece of work rather than
this section's prerequisite.

### 4a. What pruning costs, and the choice inside it

Cloning cairo proves something true: *cairo's declared source is
obtainable at the declared ref*. Prune it and a Pattern-A project — whose
worlds are all `Fetched` — never exercises its source row at all, while
`spec-check` still reports the row as declared. That is a real coverage
loss, not a free win.

| option                                                                                | keeps the claim | cost per world                                                                                                      |
| ------------------------------------------------------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------- |
| **a1** prune unconditionally                                                          | no              | 0                                                                                                                   |
| **a2** prune on CI only                                                               | on one machine  | 0 on CI — but CI stops being the same steps as local, which is the property the CI backend was just rebuilt to have |
| **a3** prune the clone, keep a remote check (`git ls-remote --exit-code <url> <ref>`) | yes             | **1.1s, 0 bytes** (measured)                                                                                        |

**Revised recommendation: a1, and move the ref check to `spec-check`**
(2026-08-27, after the audit below — §§6, 7, 8).

The earlier recommendation here was a3: keep the claim by adding a cheap
reachability action for worlds with no dependents. Three things are wrong
with it, and the audit names all three.

- **It is the special case this document argues against.** §4's own rule
  is that pruning applies uniformly to every action; a bespoke action
  existing only to keep one claim alive after pruning re-introduces
  exactly the shape §4 says would have to be undone.
- **It puts a network call in every case.** 1.1s is cheap once and not
  cheap per world per run, and it buys nothing the world under test
  claims: a world says *the lib comes from apt*, and whether the source
  ref resolves is a property of the DECLARATION, not of that world.
- **It over-claimed.** `ls-remote` establishes that a declared ref
  resolves on the remote. It does not establish that the repository is
  obtainable, complete, or buildable — which is what "keeps the claim"
  implied.

The audit's principle settles it:

> **Declaration makes an action available; dependency makes it
> necessary.**

The source row stays declared, nothing in that world depends on it, so it
does not run — a1. The obtainability question is about the declaration,
so it belongs where declarations are checked: an opt-in `spec-check`
probe, the same shape and the same second as the already-planned
`spec-check --probe-pm` (`platform.md` §7 item 1). That is what §5 below
said all along; §4a contradicted it and §4a was wrong.

The a3 row stays in the table because the DISTINCTION it draws is real
and worth keeping — *the tree is here* and *the ref resolves* are two
claims a full clone answers at once — it is the placement that was
wrong.

### 3b. What a CI job actually costs — measured on the runner

Local clone timings are a poor guide to CI, and so was my first reading
of the CI ones. Per-step spans from the cairo job (2026-08-28):

| step | run with the clone | run after pruning it |
| --- | --- | --- |
| `canary-setup` (setup-ocaml + apt + `opam install ocamlfind`) | ~40s | ~55s |
| `fetch_source` (partial clone of cairo) | **11.6s** | — (pruned) |
| `fetch_lib` (`apt-get install libcairo2-dev`) | ~6s | ~5s |
| `fetch_binding_ocaml` (`opam install cairo2`) | ~47s | ~40s |
| probes + inspects | seconds | seconds |
| **job total** | **108s** | **107s** |

**The source clone was never the bottleneck; opam is.** Removing the
clone entirely moved the total by about a second — less than the variance
between two runs of the same workflow (`canary-setup` alone differed by
15s). The two dominant costs are both opam: provisioning the switch and
installing the binding.

A correction worth recording, because it was stated confidently and
wrongly: the first workflow run took 321s and the next 108s, and that 3×
was attributed here to partial clone. It was not — at 11.6s the clone
could not account for 213s. The first run was simply the first with
`ocaml-compiler: 5.4`, so `setup-ocaml` built its cache; every run since
has hit it. Two runs are not a measurement, and "the change I just made"
is not an explanation.

So the ordering in audit §9 — eliminate, reduce, reuse — still holds, but
the target moves: after §4 eliminates the fetches nobody needs, the
reuse worth having is an **opam** cache (setup-ocaml's, plus the binding
install), not a source-repository cache.

## 5. Not in scope here, but adjacent

- **Cache the contrib tree on CI** keyed on the REPOSITORY, not on
  (repo, ref) — audit §10. Lower priority than it looked before §3b: the
  clone is 11.6s of a 108s job, so cache opam first. One repo holds every ref we track and the
  worktrees share its objects, so a per-ref key would shard the very
  thing the worktree model exists to share. The composite
  action `.github/actions/canary-setup` is the natural home; the z3
  fork's canary infra caches ccache the same way. Worth doing after §4 —
  §4 removes the fetch entirely for the worlds that pay most.
- **`git ls-remote` as a spec-check probe.** `spec-check --probe-pm`
  (`platform.md` §7 item 1) wants to validate declared package NAMES;
  validating a declared source ref is the same shape and the same one
  second.

=== audit

My recommendations, based only on the proposal as written, are:

1. **Do not use Git submodules.** Keep source acquisition inside Canary’s own execution model so fetching remains observable, testable, and tied to the specific case being run.

2. **Keep `--filter=blob:none` as the default clone optimization.** It reduces transfer/storage cost while preserving repository history semantics better than shallow clones.

3. **Do not treat `--depth 1` as fundamentally incompatible with multiple refs.** Multiple shallow refs are possible. The stronger reason to avoid shallow clones is that truncated history can affect builds that inspect Git metadata or history.

4. **Make execution demand-driven in semantics.** A declared source repository should make `fetch_source` available, but should not automatically cause it to run. Execute only actions transitively required by the case’s terminal checks or obligations.

5. **Use backward reachability as the semantic rule.** The immediate implementation can derive candidate steps and prune unused ones afterward. A later implementation can construct the graph directly from demand. Both should have the same observable result.

6. **Avoid a special case for `fetch_source`.** The rule should apply uniformly to all actions: unused provisioning, build, install, or fetch steps should disappear from the execution plan.

7. **Separate spec validation from case execution where appropriate.** If you still want to verify that a declared Git ref exists even when no executed step consumes its source tree, a lightweight check such as `git ls-remote` fits better as a spec-validation probe than as a mandatory action in every case.

8. **Describe `ls-remote` narrowly.** It verifies that the declared remote ref resolves; it does not establish that the repository is fully obtainable or buildable.

9. **Optimize CI in this order: eliminate, reduce, reuse.**

   * Eliminate unnecessary source fetches.
   * Reduce the cost of necessary fetches with partial clone.
   * Then add CI caching for source repositories that are genuinely needed.

10. **If CI caching is added later, consider caching by repository rather than strictly by `(repo, ref)`.** A shared repository containing multiple refs preserves the advantage of Git object sharing and worktrees.

The main architectural principle I would keep is:

> **Declaration makes an action available; dependency makes it necessary.**

And for the quick-versus-heavy implementation choice:

> **Backward reachability should define the semantics; demand-driven graph construction can later optimize the implementation.**

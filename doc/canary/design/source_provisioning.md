# Getting the source

**Kind: rationale.** How canary obtains a project's source, what that
costs, and why it is shaped this way. Everything here exists.

A cross-pass topic, not a stage: declaring a repo is
[pass 1](enumeration/stage1_declare_spec.md), realizing a fetch is
[pass 5](enumeration/stage5_realize_steps.md), and the facts worth
knowing sit between them. Same reason
[`staged_parity.md`](staged_parity.md) is not under `enumeration/`.

## 1. The shape

A `source_repo` declares a remote and a ref. `worktree_ensure_cmd` turns
that into **one checkout per repo plus one `git worktree` per ref**:

```
<contrib_root>/<project>-all/<repo>          the clone — shared objects
<contrib_root>/<project>-all/<repo>-<ref>    a worktree per tracked ref
```

Neither path contains a scenario, so **every world shares them**. z3
tracks three refs (`latest` / `arbipher` / `pre-10549`) in one repo this
way, which is what makes `--refs latest,pre-10549` a regression pair
rather than two clones.

On CI the machine root is `$GITHUB_WORKSPACE`, so a job starts cold and
the same commands clone into the runner's workspace.

## 2. Not git submodules

1. **It would delete an action canary tests.** `fetch_source` is in the
   action catalogue with a `check_post`, an expectation and graph edges.
   Canary's subject is provisioning — `Fetched | Built | Installed |
   Vendored` — so obtaining a source is *a step that can fail*, not a
   precondition. A submodule makes it ambient.
2. **One submodule pins one SHA; canary needs several refs per repo.**
   As submodules, z3's three refs are three submodules of one upstream,
   or a pointer mutated per scenario.
3. **CI gets slower.** `actions/checkout` resolves submodules at job
   start, before it knows which scenario runs — the sqlite job, whose
   source is a curl'd amalgamation, would pay for llvm-project. Selective
   init is a per-job step again, i.e. what exists now but implicit.
4. **It reverses a standing decision** (`~/.claude/CLAUDE.md`): shared
   third-party checkouts live in one contrib tree, *"no submodules, no
   copies"*, so projects share one source tree and one warm build cache.

## 3. Partial clone, not shallow

```
git clone --filter=blob:none <url> <main>
```

Measured on cairo:

| shape | `.git` | clone | second ref via `worktree add` |
| --- | --- | --- | --- |
| full | 106M | 9.8s | works |
| `--filter=blob:none` | 44M | 8.3s | works — +1.1s, +4M |
| `--depth 1` | 34M | 4.5s | works, with an explicit refspec |

Shallow is cheapest and unusable: it truncates history, and inside a
`--depth 1` worktree `git log --oneline | wc -l` is **1**. Our
source-built projects are the ones that ask — z3 and LLVM derive version
information from git metadata, and there is a recorded cmake-vs-git
failure in the z3 checkout. Partial clone withholds blobs, not history,
so every such query still gets the true answer.

(Shallow *can* serve multiple refs, given `+refs/tags/X:refs/tags/X`
rather than a bare `git fetch origin X`, which only updates `FETCH_HEAD`.
History is the objection, not refs.)

The checked-out tree is 71M of cairo's 177M and identical under all three
shapes — clone shape cannot fix a checkout that was not needed. §4 is
what does.

## 4. Only what a world consumes is realized

`derive_steps` walks the catalogue and realizes what a project
*declares*, which for a fetch is not always what a world *needs*: cairo's
all-`Fetched` world cloned a repository whose tree no later step read.

```
drop a Fetch k when no step in this world consumes k
```

asked of the typed catalogue (`consumes_of_action` /
`produces_of_action`, pinned by `consumes_produces.*`), not of
`step.deps`.

**Only fetches, because a fetch is the only action class with no
inputs** — `(Fetch Source, [], [Source])` against `(Build_lib, [Source],
[Lib])`, `(Probe_lib, [Lib], [])`. Everything else consumes something and
is therefore always attached to the graph; a fetch is the only node that
can be orphaned. Its input is really the world's *ambient store*, which
is the same fact seen from the other side.

A declared source row stays declared: `spec-check` still reports it, and
whether its ref resolves is a question about the declaration, tracked
with `spec-check --probe-pm` in [`platform.md`](platform.md) §7.

Pinned by `derive.steps_are_demanded` as a pair — cairo's world must lose
`fetch_source` while keeping its probes; every sqlite world with
`build_lib` must keep it. Either half alone is satisfiable by a broken
rule.

## 5. Prepare once, ensure per world

The checkout is shared but the marker is per-world, so N worlds at one
ref each ran a full fetch to converge on a tree that was already right.
The command separates the question by who is asking:

| half | question | scope | guard |
| --- | --- | --- | --- |
| clone / fetch / worktree add | *has the ref moved?* | the **run** | sentinel `<main>-refreshed-$CANARY_RUN_ID` |
| checkout + marker | *is this world's tree here?* | the **world** | none; it is cheap |

`CANARY_RUN_ID` is a process-lifetime stamp (`Canary_store.run_id`)
exported into every step's shell beside `OPAMSWITCH`. A process *is* a
run: `canary action <p>` executes every world of a project in one, and a
GH job runs exactly one — which is the scope in which `latest` is fixed.

```
first world in a run   0.317s     consults the remote
next world, same run   0.004s     sentinel hit, no network
first world, new run   0.278s     refreshes again
```

So a moving ref still refreshes once per run: refresh-on-demand is
preserved, not traded for speed. Stale sentinels are swept before a new
one is written. On CI the variable is unset and the workspace cold, so
the remote half runs — what a fresh runner needs.

Pinned by `source.refresh_is_run_scoped`, a SHAPE check: the clone must
sit **inside** the guard and the marker write **outside** it. Swap either
and a world re-fetches, or stops recording its own evidence.

### The other fetch kinds are deliberately not converted

| kind | redundant cost per extra world | state |
| --- | --- | --- |
| git source | 1.1s | converted (above) |
| apt / brew | **0.40s** | not converted |
| opam pin | ~0s when the pin is held | covered elsewhere: the fetch is pin-checked, so the run cache warm-skips it. A real pin flip (~5.2s) is work, not waste |
| conda-forge prebuilt | ~0s | `Canary_prebuilt.is_prepared` + the `prebuilt` subcommand prepare out of band |
| curl archive | ~0s | sqlite's `build_lib` carries a `test -d … \|\|` guard inline |

0.40s is below a run's own variance, so converting apt/brew would be
optimising noise — and it carries a trap the git case does not. The
obvious guard, `verify_installed_cmd`, asks whether the package *exists*:
a world declaring version X would be satisfied by installed version Y,
which is the false pass canary exists to catch. The right predicate is
`Canary_pm.installed_version_cmd` against the declared version — the apt
analogue of `holds_pin_cmd`.

## 6. What a CI job actually costs

Per-step spans, cairo job, `ubuntu-latest`:

| step | |
| --- | --- |
| `canary-setup` (setup-ocaml + apt + `opam install ocamlfind`) | 40–55s |
| `fetch_binding_ocaml` (`opam install cairo2`) | ~40s |
| `fetch_source` (partial clone, when a world needs one) | 11.6s |
| `fetch_lib` (`apt-get install`) | ~6s |
| probes + inspects | seconds |
| **job total** | ~108s |

**Opam dominates; the source clone never did.** Two consequences: caching
work belongs on the opam switch rather than the contrib tree, and a
workflow's first run is much slower than its later ones because
`setup-ocaml` is building its cache — a gap large enough to swamp
anything inferred from two runs.

## 7. Open work lives in trackers

| item | tracked in |
| --- | --- |
| Pass 5 receives commands, not the world — so §4's question is answered a pass after `source_is_read` already asks it | [`enumeration/README.md`](enumeration/README.md) *Known drift* |
| `prepare` as a dispatched action rather than a guard inside the fetch | same entry |
| Caching opam on CI | [`../project/issues.md`](../project/issues.md) §2 |
| Caching the contrib tree, keyed by repository — below opam in priority | same |
| Validating a declared source ref without fetching (`git ls-remote`, 1.1s) | [`platform.md`](platform.md) §7 |

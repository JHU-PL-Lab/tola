# The constraints — why the product is not the answer

**Kind: rationale.** Written 2026-08-23 because it did not exist: the
product over (provision × version × mutation) is easy and documented
(§1 below), but what makes
the enumeration *correct* is the five constraints that prune it, and
those lived only in comments inside `canary_enumerate.ml`. Every one of
them exists because a specific over- or under-generation was observed.

Read [`README.md`](README.md) first for where this sits (stage 2).

## The order they run in

```
run_config          product, each level resolved PER ARTIFACT
  │                 (provision × version, version additionally per-provision)
  ▼
assignment_ok       ── coherence: does this world make sense at all?
  ▼
ax_follows          ── declared coupling (Lockstep mode only)
binding_couples     ── a Built binding matches its own source's channel
source_ref_ok       ── the unread-source collapse
  ▼
shadow_filter       ── a prebuilt shadows a same-cell Built
  ▼
ref_filter          ── the --refs subset
```

The three middle checks run in one pass over the artifacts, guarded by
`version_mode = Lockstep`; `Independent` skips them and gives the raw
free product.

## 1. `assignment_ok` — coherence

Four rules, all about whether a world could exist:

- A **Built or Installed lib needs its source present**, and at the same
  **channel**. Channel-level, not id-level: identity-bearing sources
  (a `Repo_axes` family's per-channel repos) carry ids the lib's
  placement can never mirror, and under id-equality both dev build chains
  would die. WHICH checkout the scenario is remains part of identity —
  it is the source placement's id (`source-fetched-latest` vs
  `source-fetched-arbipher`).
- The check is **skipped when `a_source` is not declared**. A project
  that models Built as self-contained (sqlite fetches its own
  amalgamation) omits the source artifact, and the coupling is moot.
- A **binding needs a lib**. Provided-or-Absent, per binding.
- An **app needs some binding**.

`Installed` joins `Built` here as the "built family" (2026-08-18): an
installed lib was built from source at that channel too.

## 2. `ax_follows` — the declared coupling

A project can declare that one artifact's version FOLLOWS another's
(`artifact_row ~follows`). The filter keeps only assignments where the
follower's channel equals the leader's — unless either is unprovided.

This is the blunt instrument, and its cost is why the next two exist:
the source rows used to carry `~follows:a_lib`, which killed the phantom
refs but also **forbade the FORWARD cell** — a binding built from a dev
tree probed against the released lib. That is a genuine world, and the
one most likely to find a real bug.

## 3. `binding_couples` — source-primary for a built binding

A **Built** binding builds FROM the scenario's source, so its channel
must match that source's — the same source-primary rule as the Built lib.
Its own source, note: `binding_source_of` resolves the per-language
binding source (`Binding_source lang`), which may be a different repo
from the lib's (zarith's binding is `ocaml/Zarith`, its lib is the system
gmp).

Only the source couples. The **lib pairing stays free**, which is exactly
what leaves the forward cell (Built binding × Fetched lib) alive.

## 4. `source_ref_ok` — the unread-source collapse

The phantom-ref rule, stated precisely (2026-08-19).

A world where **nothing is built from a source** still fetches it, but
WHICH ref it names changes nothing observable — so N declared refs would
produce N identical runs. Such a world keeps only the source's
**canonical pin** (the first declared; stable-first by convention).

"Read" is defined by `source_is_read`: the lib builds from the project
source (`Built` or `Installed`), or some binding is `Built` from that
source. Nothing else consumes a source.

Measured effect: llvm 5 → 3 scenarios, zarith 3 → 2, and z3's
all-Fetched worlds collapsed to ONE (its three fetched rows named
different refs over the same lib and binding).

## 5. `shadow_filter` — prebuilt shadows source

When a Built placement and a prebuilt one (`Fetched`/`Vendored`) would
materialize the **same cell** — same artifact, same channel, same
version id, everything else identical — the prebuilt wins and the Built
assignment is dropped.

The belief: a same-version prebuilt, built by someone else's script,
behaves like a self-built one. The rule came from the GMP build session
(user, 2026-08-17): building an external C lib is not reliably easy, so
the source-built path should not appear automatically.

Firing is **identity-bearing same-version**: both ids must be non-empty
and equal. An ambient (unpinned) prebuilt never shadows — the
same-version belief needs the version known on both sides. sqlite's built
amalgamations are NOT the system's, so they do not shadow.

**Unconditional since 2026-08-19.** It first landed as a two-valued
policy with an `Audit_lib` run rung and an `--audit-lib` flag to unhide
the Built column; nothing used it, and a project that wants its
source-built lib visible should declare it as a **distinct version**
rather than ask a run flag to unhide it. See
[`../wrapper_packages.md`](../wrapper_packages.md) §3.

## 6. `ref_filter` — the `--refs` subset

Keeps the assignments whose SOURCE placement's pinned id is in the
requested list (`--refs latest,pre-10549`). Orthogonal to the version
axis: thin (a channel subset) and refs (an id subset) compose. Projects
with no declared/pinned source are unaffected.

This is a **selection**, not a semantic constraint — it belongs to the
run, not to the model. Folding it into ONE general selection mechanism
(channels, refs, scenarios, actions, …) is an open item in
`../../project/status_project.md` §2.

## What the constraints do NOT do

They do not remove worlds that are merely *expected to fail*. A pruned
assignment is one that could not exist or could not differ; a world that
exists and breaks is the point of the exercise, and its verdict is an
expectation, not a filter. The forward cell surviving §2's cost is the
clearest statement of that principle in the code.

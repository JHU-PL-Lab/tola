# Stage 3 — selection: what this run asked for

**Kind: rationale.** Standalone. Pass 3 of six. Stage 2 says which worlds
the project HAS; this pass narrows them to the ones a particular run
wants. It changes nothing about what exists. The map is
[`README.md`](README.md).

> Moved here 2026-08-24 from `emit_stages.md` §7, where the analysis was
> written, once the pass landed and earned a stage of its own. The user's
> question that opened it: *"are the possible config/policy issues either
> functions from stage 2 to stage 3, or just a stage 3 refinement?"*

*(2026-08-24, user: "are the possible config/policy issues either
functions from stage 2 to stage 3, or just a stage 3 refinement?")*

**Neither, as asked — because "config/policy" is currently three
different things.** Separate them and only one is a 2 → 3 function, and
it is the one the question is pointing at.

| kind | examples | where it belongs |
| --- | --- | --- |
| **model constraints** | `assignment_ok`, `binding_couples`, `source_ref_ok`, `shadow_filter` | stage 2, **unconditional** — they say a world cannot exist or is indistinguishable. Turning one off does not buy coverage, it buys wrong or duplicate worlds |
| **selection** | `--thin`, `--refs`, and the queued scenario / action / project selectors | **its own pass, 2 → 3** |
| **run configuration** | `pr_tier` Heavy/Light, failfast, root, parallelism | stage 4 and later — not about which worlds at all |

Two pieces of evidence that the tree already knows this:

- `shadow_filter` shipped with a `Shadow_prebuilt | Materialize_source`
  knob and an `Audit_lib` run rung, and both were **removed** on
  2026-08-19 (user: *"I think we remove this feature"*). That was
  recognizing shadowing as model rather than policy — the knob existed
  because it had been misfiled.
- [`stage2_filters.md`](stage2_filters.md) §6 already says `ref_filter`
  is *"a selection, not a semantic constraint — it belongs to the run,
  not to the model"*. The generalization is that the *category* is
  missing, not that one filter is misplaced.

### Why a pass, and not a stage-3 refinement

The honest part first: **selection commutes with all of stage 3.**
Selecting then dedup/order/group gives the same result as
dedup/order/group then selecting — dedup keys on the pin id and so does
`--refs`, and a stable sort preserves relative order under filtering. So
correctness does not decide this, which is exactly why the question feels
ambiguous. Legibility does, and three arguments agree:

- **Stage 2's output becomes invocation-independent** — "every world this
  project has", a fact about the project rather than about today's flags.
  That is what makes `emit --stage 2` diffable across runs, and it
  sharpens `matrix.registry_shape`, which today pins 42 rows *under the
  default config* while reading as a statement about the enumeration.
- **"Why isn't this running?" splits into two answerable questions** —
  *it does not exist* (a stage-2 constraint) versus *you did not ask for
  it* (selection). Today both look identical, which is precisely what §6
  is trying to fix.
- **One question per stage.** Stage 3 doing identity, exclusivity, order
  *and* selection is the same violation the doc reorganization has been
  removing.

### The wrinkle to know before implementing

**`--thin` acts BEFORE the product; `--refs` acts AFTER it.**
`resolve` / `resolve_versions` restrict each artifact's universe and the
product is built from what is left; `ref_filter` runs on the finished
assignment list. They cannot be unified while they act in different
places.

They are equivalent for the levels actually used — restricting a factor
of a product equals filtering the product on that factor, and `Subset`
*intersects* the universe, so an artifact with no matching version simply
contributes no placement (which is how thin z3 drops the `Built`
provision and keeps the fetch chain). `Free` ("the head of the universe")
is expressible as a post-filter but awkward, and it is tiny-only. So thin
can move to the post-filter side without changing any current result. The
cost is building a larger product first, which at today's sizes is
nothing.

**A symptom worth naming**: there are two `run_config`s in one pipeline.
`Canary_enumerate.run_config` is the *function* that resolves levels into
points; `Canary_project_run.run_config` is the *record* of a run's
settings. And `enumeration_policy_of : run_config -> policy option` maps
one into the other — category 3 reaching into category 1's machinery, in
a single line.

### What it costs, and how it lands with `emit`

1. Move `--thin`'s level resolution to the post-filter side, beside
   `ref_filter`. The equivalence above says no result changes, and
   `matrix.registry_shape` + `enumerate.thin_is_version_subset` prove it.
2. Name the pass: one `select : selection -> assignment list ->
   assignment list` in `action/canary_enumerate.ml`, with `selection` the
   single record the tracker's "ONE general SELECTION config" item wants.
3. Rename one of the two `run_config`s.

Then `emit --stage 2` is the project's worlds, `emit --stage 2.5 --why`
is what you asked for and what you did not, and stage 3 goes back to one
job. The two changes are worth doing together: `--why` is what makes the
split visible, and the split is what makes `--why` answer two different
questions instead of one blurred one.


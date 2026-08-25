# Pass 3 — select: what this run asked for

**Kind: rationale.** Standalone. Pass 3 of five. Pass 2 says which worlds
the project HAS; this one narrows them to the ones a particular run
wants. It changes nothing about what exists. The map is
[`README.md`](README.md).

> Landed 2026-08-24, from the user's question: *"are the possible
> config/policy issues either functions from stage 2 to stage 3, or just
> a stage 3 refinement?"* The analysis was written in the `emit`
> proposal; it moved here once the pass existed. Revised the same day so
> it describes the code rather than a plan.

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
- [`stage2_filters.md`](stage2_filters.md) §6 had already said `ref_filter`
  is *"a selection, not a semantic constraint — it belongs to the run,
  not to the model"*. The generalization was that the *category* was
  missing, not that one filter was misplaced.

### Why a pass, and not a refinement of pass 4

The honest part first: **selection commutes with all of pass 4.**
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
  *it does not exist* (a pass-2 constraint) versus *you did not ask for
  it* (this pass). Before the split both looked identical.
- **One question per pass.** Pass 4 doing identity, exclusivity, order
  *and* selection would be the same violation the doc reorganization has
  been removing.

### How it is built

```ocaml
type selection = { sel_version : channel level; sel_refs : source_ref_level }

let enumerate ~tag ~policy s =
  enumerate_product ~tag ~policy:(unselected policy) s
  |> select (selection_of_policy policy)
```

`unselected` widens the version and refs axes; `select` narrows them
afterwards. So pass 2 sees the whole declared space and pass 3 applies
what the run asked for.

**The equivalence this rests on, and why it is checked rather than
argued.** Before the split, `--thin` acted BEFORE the product
(`resolve_versions` restricted each artifact's universe) while `--refs`
acted AFTER it (`ref_filter` ran on the finished list). Moving thin to
the post-filter side is safe because restricting a factor of a product
equals filtering the product on that factor — and `Subset` *intersects*
the universe, so an artifact with no matching version contributes no
placement, which is how thin z3 drops the `Built` provision and keeps the
fetch chain.

That argument is not self-evident here, because the product is followed
by five constraints and one of them (`shadow_filter`) is
CROSS-assignment. So it is a pin, not a paragraph:
`select.thin_post_filter_equals_universe_restriction` runs both forms
over every catalogued project. Two more guard the pass's shape —
`select.is_a_subset_of_stage2` (selection only ever removes, so pass 2
stays the honest inventory) and `select.full_policy_selects_everything`
(the default asks for everything).

`Free` — "the head of the universe" — has no post-filter form that means
the same thing, and no policy reaching `enumerate` uses it on the version
axis. The slice functions that do (`tiny_slice`, `general_slice`) build
points directly and never pass through `select`.

The cost is building a larger product before narrowing it, which at
today's sizes is nothing.

### What it looks like

```
$ canary emit z3 --stage enumerate   → 16 worlds the project HAS
$ canary emit z3 --stage select --thin        → 1 of 16
$ canary emit z3 --stage select --refs latest → 5 of 16
```

That is the split's whole point: "why isn't this running" now has two
different answers — *it does not exist* (a pass-2 constraint) versus
*you did not ask for it* (pass 3). `--why` will report them separately
([`stage2_filters.md`](stage2_filters.md) *Attribution*); before the
split it could only have said "absent".

### Still open

**Two `run_config`s in one pipeline.** `Canary_enumerate.run_config` is
the *function* that resolves levels into points;
`Canary_project_run.run_config` is the *record* of a run's settings. And
`enumeration_policy_of : run_config -> policy option` maps one into the
other — run configuration reaching into the enumeration's machinery, in a
single line. Renaming one of them was step 3 of the plan and was not
done; it is cosmetic but it is exactly the confusion this doc exists to
undo.

**One general SELECTION config.** `selection` covers the version and refs
axes. The tracker's standing item wants one mechanism over every choice a
run makes — channels, refs, scenarios, actions, projects — rather than a
flag per axis. `selection` is the shape that item should grow into, not a
second thing beside it.

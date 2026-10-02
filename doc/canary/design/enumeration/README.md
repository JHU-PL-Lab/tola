# The enumeration — the map

**Kind: index.** What is in this directory, which file answers which
question, and what is deliberately somewhere else.

**The dataflow itself is [`pipeline.md`](pipeline.md)** — four IRs, six
passes, the pass table with each pass's code and tests, and the
invariants. That used to be this file's middle, which made the map and
the thing it maps one document.

> Created 2026-08-23 from the design/ audit. The problem it fixed: nine
> docs all described the enumeration, but each was written from the
> *occasion* that produced it (a rerun, a user question, a landing)
> rather than from a *stage* of the pipeline. A reader could ask "what
> happened on 2026-08-19?" and get a good answer, but not "what happens
> between the product and the assignment list?" — which is where the
> subtle parts live. Split into map + pipeline on 2026-09-17.

## How to read this, if you are new

Four steps, ~45 minutes, and you can stop after any of them:

1. **[`pipeline.md`](pipeline.md), top to bottom** (~10 min). The six
   passes, how to look at one, why layers and passes are different axes,
   and the five invariants. Enough to talk about the enumeration and to
   know where anything lives.
2. **Run it against a project** (~5 min). Reading beats being told:

   ```sh
   canary emit sqlite --stage declare      # what the project states
   canary emit sqlite --stage analyse      # what canary makes of it
   canary emit sqlite --stage enumerate    # 10 worlds it HAS
   canary emit sqlite --stage order        # the same 10, grouped by store state
   canary emit sqlite --stage realize      # one scenario's steps
   ```

   z3 is the richest spec (16 worlds, both cross cells) and is muted, so
   it is the best thing to dump and the safest to not run. Compare
   `--stage enumerate` with `--stage order` on sqlite: same ten
   scenarios, and the second shows why the run order is not the
   enumeration order.
3. **The pass whose behaviour you need** — one doc each, below. If you
   are landing a project, read [pass 1](stage1_declare_spec.md) and stop;
   it is what you will actually write.
4. **The vocabulary** ([`stage0_naming.md`](stage0_naming.md)) when a word
   stops being obvious — "scenario" has four senses and they are all in
   use.

## Which file

| you are… | read |
| --- | --- |
| **changing how scenarios are produced** | [`pipeline.md`](pipeline.md) — start there whatever else you do |
| landing a project | [pass 1, declare](stage1_declare_spec.md) — it is what you will actually write |
| asking what canary makes of a spec | [pass 2, analyse](stage2_analyse_spec.md), or `canary emit <p> --stage analyse` |
| wondering why a world is missing | [pass 3, enumerate](stage3_enumerate_worlds.md) (the five constraints), then [pass 4, select](stage4_select_worlds.md) (was it asked for?) |
| debugging run order, or an opam pin dance | [pass 5, order](stage5_order_worlds.md) |
| adding an action or a command template | [pass 6, realize](stage6_realize_steps.md), then [`../action_playbook.md`](../action_playbook.md) |
| asking **when a check fires** | [pass 6](stage6_realize_steps.md) §2b — the occasion is this directory's; the claim is not |
| unsure what a word means | [`stage0_naming.md`](stage0_naming.md) |

Filenames are `stage<N>_<verb>_<IR out>.md`, so a directory listing
carries the reading order, the verb, and where the IR lowers — the
convention is explained in [`pipeline.md`](pipeline.md).

**The two proposals** here are not passes:
[`multi_lib.md`](multi_lib.md) (a second C lib — naming landed
2026-08-25, `rp_build` and a per-slot action role remain) and
[`resolve_placements.md`](resolve_placements.md) (nothing resolves a
placement to a concrete location, and three types describe one idea).
[`../staged_parity.md`](../staged_parity.md) is cross-cutting: it
perturbs pass 1 (Installed is a provision, so a staged consumer is a
world) and pass 6 (build-vs-install parity is a check).

## Where the code is

`project/canary_project_analysis.ml` is pass 2;
`action/canary_enumerate.ml` is passes 3 and 4;
`project/canary_project_run.ml` is passes 1 and 5;
`action/canary_step_builder.ml` is pass 6; and
`main/canary_pipeline.ml` names them all in order — that one is the
30-second version of [`pipeline.md`](pipeline.md).

## What is NOT here

- The **cache** — `../artifact_cache.md` (proposal) and
  [`stage6_realize_steps.md`](stage6_realize_steps.md) §4 (what exists).
- **Adding an action** — [`../action_playbook.md`](../action_playbook.md);
  what an action IS, and what `_post` means, is
  [`../action_model.md`](../action_model.md).
- **Reporting** — [`../matrix.md`](../matrix.md). The run record
  (`canary overview --json`) reads `actions.log` after a run, so it is
  a CONSUMER of the pipeline's
  output, not a pass in it. It was numbered as one until 2026-08-24.
- What a check **CLAIMS** — `../agreement/`, and start at its
  [`README.md`](../agreement/README.md).

  **THE SEAM, drawn (2026-09-16):** *agreement/ owns the CLAIM,
  enumeration/ owns the OCCASION.* A claim is what an agreement asserts,
  whose rule it recovers, and what falsifies it — none of which mentions
  a world. An occasion is `(world, action, mechanism, lang)`: which step
  a check fires at, and where its evidence is. The split lands in three
  places:

  | | lives in |
  | --- | --- |
  | applicability — can this PROJECT carry the claim? | pass 2, [`stage2_analyse_spec.md`](stage2_analyse_spec.md) |
  | firing + evidence address — does it fire HERE, and where does it read? | pass 6, [`stage6_realize_steps.md`](stage6_realize_steps.md) §2b |
  | the claim itself | `../agreement/` |

  The old line here sent *"which contract fires"* away, which was wrong
  in both directions, and it pointed at `surface/` — a directory renamed
  to `agreement/` on 2026-09-01 and so dead for a fortnight.

  **Still crossed in CODE, and recorded rather than patched:**
  `binding_evidence_tag` / `lib_evidence_tags` map a world to a step tag
  — world-arranging by nature — and live in
  `agreement/canary_agreement_common.ml`. Moving them is not the fix;
  `Canary_project_analysis.producers_of` plus the world's provision
  computes the same function from the declarations, and deriving it is
  what closes the placement class (backlog §50). A derived map does not
  need an owner.
- Anything **per project** — `../../project/`.

## The alignment rule

[`pipeline.md`](pipeline.md)'s pass table names the tests for each pass.
Each one is a registered test — `canary project-test` prints them — so
when you land a change to a pass, the fastest check is whether that
pass's tests still exist and still pass.

**Test names are not renumbered.** `select.is_a_subset_of_stage2` was
named when enumerate was pass 2 and still says `stage2`; the 2026-09-16
renumbering left every test name alone. A test name is an identifier that
appears in logs, in the pass table and in `canary project-test` output,
and renaming it to track a doc's numbering would break the one thing the
name is for — being greppable across history. Read a `stageN` inside a
test name as a historical label, not as a claim about today's table.

**One citation had gone stale, and it is the case the removed check
would have caught** (found 2026-09-17 by running the suite and diffing
its test names against every dotted name this directory cites). The pass
table named `scenario.lower_expectation_agnostic_c1`; the test is
`..._symbols`, renamed when the `c1`..`c9` ids were retired on
2026-09-12. One stale citation in seven stage docs over three weeks is a
low rate — worth knowing when deciding whether backlog #48 earns its
cost, and worth doing by hand after a rename until it does:

```sh
canary project-test | grep -oE '^\[(PASS|FAIL)\] [a-z0-9_.]+' | awk '{print $2}' | sort > /tmp/tests
grep -ohE '`[a-z][a-z0-9_]+\.[a-z0-9_]+`' doc/canary/design/**/*.md | tr -d '`' | sort -u | comm -23 - /tmp/tests
```

**Not automated.** A check that failed the build when a doc cited a
deleted test was built and removed on 2026-08-23: it worked, but it was
one narrow instance of a general problem (docs citing tests, docs citing
source paths, comments citing docs, docs citing CLI verbs), wired to one
directory with a hand-maintained exclusion list. The general form is
backlog #48. Until it exists this is a convention, not a guarantee — and
so is the converse, which no check would cover anyway: a test can exist
while the prose around it describes something the code stopped doing.

**What to be skeptical of.** Where a doc and the code disagree, the code
is right and the doc is a bug. `canary project-test` is the arbiter — a
claim with no test behind it is the one to distrust first.

# Pass 2 — analyse: `spec → spec, enriched`

**Kind: reference.** What canary DERIVES from a project's declaration
before any world exists. Read this when a report and a run disagree
about what a project checks, or when you are about to compute something
from a spec and want to know whether it belongs here.

> Added 2026-09-16 (user). The pass did not exist; its derivations did,
> one function at a time, computed on demand by whoever needed one. The
> renumbering that made room for it — declare(1), analyse(2),
> enumerate(3), select(4), order(5), realize(6) — was the user's call on
> the trade: *"a clean model for pass as well as action / project is
> more worthy"* than four file renames and a citation sweep.

## 1. What it is

```
project_spec                                  (pass 1's output)
  ▼ Canary_project_analysis.of_project_run
Canary_project_analysis.t                     what canary UNDERSTANDS
```

A project author writes a `project_run`: artifact rows, binding
declarations, an `api_source`, command templates. That is the RAW spec
and it is deliberately flexible. What canary reasons with is a set of
derived facts over it, and until this pass they had no home.

| field | what it is |
| --- | --- |
| `an_spec` | pass 1's `project_spec`, carried rather than recomputed |
| `an_chains` | the universal chains this spec admits — `chain_applicable` over the 38 |
| `an_declared` | what the project says it ships: the source repo's `api_source`, else its own |
| `an_mechanisms` | one `(lang, mechanism)` per language this project DECLARES a binding for |
| `an_unsuited` | the claims it cannot carry, per language, with the reason |
| `an_touches` | **the join** — for each action, which DECLARED artifacts it consumes and produces |
| `an_carries` | and the positive form: the agreements it CAN carry, per language |

See it:

```sh
canary emit sqlite --stage analyse
canary emit z3     --stage analyse --json
```

## 2. The membership rule: the absence of a world

**A fact belongs in pass 2 if it needs no world.** That is the whole
rule, and it has a sharp test case either side of it:

- **applicability** is `mechanism → lang → declared → Applicable |
  Inapplicable why`. No assignment appears. It is knowable from the spec
  alone, so it belongs here.
- **firing** is `mechanism → lang → world → action list`. It cannot be
  answered without a world, so it stays at [pass
  6](stage6_realize_steps.md), where the runner attaches an
  `agreement_ctx` to each step.

Putting firing here would mean inventing a world, which is pass 3's job.
Putting applicability at realize is what the codebase did until
2026-09-14, and it restated one static fact once per step — sqlite
emitted the same six `not_applicable` sentences on each of ten
scenarios.

## 3. Why it is a PASS and not a sibling

A sibling was the first proposal: leave the pipeline at five passes and
hang the analysis off pass 1 as a second branch. That was wrong, and the
pass table said so before anyone argued it.

The table already carried **one** unnumbered `*(branch)*` row —
`chain_applicable`, spec → chains — and the README's *open question*
listed it among the accidents it wanted redrawn: *"chain applicability
with nowhere to live — a real spec-only derivation that is neither a
pass nor a dump, and hides inside `patterns_of`"*. Adding a second
branch would have doubled the thing that was already regretted.

So: linear (user, *"can we do them in linear, so … every IR is clean"*),
and the existing branch folds INTO it. `an_chains` is that branch, now a
field of a numbered pass.

**Pass 2 does not lower its IR, and that is fine.** `an_spec` carries
pass 1's value forward unchanged, so what pass 3 reads is what pass 1
wrote. Passes 4 and 5 do not lower either — the filename suffixes say so
at a glance (`_spec` twice, `_worlds` three times). A pass is a place
where a derivation happens, not necessarily a place where a
representation changes.

## 4. What it fixed: three views, two answers

The cost of having no name for this was measured, not theorised.

**2026-09-15.** Two views of "which checks apply to this project" —
`Canary_matrix`'s result columns and `Canary_check_index` — each derived
the answer separately, and they disagreed. The index asked applicability
with the project's FIRST declared binding for every action, so sqlite's
Python probe reported that nothing fires there, while the result table
carried five Python check columns and the run log had decided
`api_names_present` on that step twelve times. Three views of one
project, two answers. `checks.index_speaks_each_action_language` tests
that instance.

**2026-09-16, the cause.** Both views built their own
`(mechanism, declared)` pair on the way into `suits_here`, and they
built them differently: the result table used the LANGUAGE DEFAULT
(`mechanism_of_lang_exn`), the index used the project's DECLARATION.
Those differ wherever a project declares a non-default mechanism — z3
and llvm bind Python through `Ctypes`; Python's default is `Cext` — and
applicability genuinely turns on the difference, because Ctypes compiles
no stub and records no dependency. On z3, the declaration says 5 claims
are carryable on the Python side and the language default says 9.

No output moved when this was fixed, because no project's chain puts
such a language in front of the result table today: llvm derives no
Python step and z3 is muted. That is the point — it is the same
divergence as the 2026-09-15 one, caught before it fired.
`checks.applicability_reads_the_declaration` tests the direction at the
one project where the two answers differ.

## 5. The join — actions × declarations

`an_touches` answers, for every action in the catalogue, which of THIS
project's declared artifacts it consumes and produces — in the project's
own artifact IDENTITIES, not in coarse kinds.

It is here because it is spec-only: no world, no policy, no realized
step. It exists because a HOOK needs it. `<action>_post` is a trigger
moment, not a specification of what runs there, so what runs has to be
derived from what the action just produced — which means something has
to be able to say what that is. Nothing could.

| function | question |
| --- | --- |
| `touches an action` | what does it touch here? `None` = not in this project |
| `produced_at an action` | the hook's question — what did it just make? |
| `producers_of an artifact` | backwards — where could this artifact's evidence come from? |

Two lists rather than one: a hook reads the produced side, a
precondition the consumed side. Lists per kind rather than a first
match, because tiny-full already declares two apps and two Python
bindings and `A_lib of string option` was landed for a second lib.

Tested by `analysis.touches_joins_actions_to_declarations` (total over
the declarations; a `Probe_*` produces nothing; a lib has more than one
producer). The model it serves is
[`../action_model.md`](../action_model.md); what is NOT built on it yet
is that doc's §6.

## 6. Asking the analysed spec things

One value; every question below used to be asked by rebuilding its
inputs somewhere else:

| function | question |
| --- | --- |
| `carries t ~lang slug` | can this project decide this AGREEMENT here? (the run record's check columns) |
| `suits t ~lang m` | …this METHOD? (the check index, which counts methods) |
| `mechanism_for t lang` | what does this project bind this language through? |
| `langs t` | which languages does it declare? |

`an_carries` is `carried_slugs` memoised. `carries` and `suits` are the
same predicate at two granularities: `carries` is `exists m. m has an
evaluator ∧ suits m`, plus the registry row's own enabled flag. Both
filters are about not spending a column on a cell that can never say
anything — a method with no evaluator reports `not_implemented` forever,
one the project cannot carry reports `not_applicable` forever, and
neither is coverage.

## 7. Two lists of languages, deliberately

`an_mechanisms` and `an_carries` are keyed differently and it is not an
oversight.

- `an_mechanisms` holds the languages the project **declares**, because
  it drives `an_unsuited`, which is a REPORT about this project. Asking
  a one-binding project what its absent Python side cannot carry is the
  bug this pass fixed on the way in: `Canary_pipeline.unsuited_of`
  iterated the registry-wide `[OCaml; Python]` and answered at length
  about a binding that does not exist.
- `an_carries` is keyed over the **modelled** languages, because its
  consumers ask about whichever language an ACTION names, and dropping a
  language would silently drop columns. A language with no declared
  binding is answered with its default mechanism, which is what both
  consumers already did.

## 8. ⚠ A declaration this pass does not read

A project can state its binding mechanism in **two** places, and pass 2
reads one of them.

- `pr_binding_decls` — a `binding_decl` list. sqlite, z3, llvm, zarith,
  ssl and torch use it, and it is what `mechanism_of` reads.
- the artifact table's `a_binding lang mech` row. The opam-binding
  template fills this from its own `binding_mechanism` field and leaves
  `pr_binding_decls` EMPTY, so cairo, libffi, zlib and zstd declare a
  mechanism that pass 2 never sees.

The consequence is visible in `canary emit libffi --stage analyse`: it
reports `ocaml cstubs` and `python cext`, both language defaults. libffi
declares `Ctypes` on its artifact row, and it declares no Python binding
at all — which is where the phantom Python `signatures_agree` claim in
its `an_unsuited` comes from.

**Not fixed here, on purpose.** Reading the artifact table would move
libffi's OCaml mechanism from Cstubs to Ctypes, and Ctypes is
inapplicable for `required_symbols_exported`, `dependencies_provided`
and three more — so four currently GREEN cells on libffi's result table
would become `not_applicable`. Whether that is a correction or a
misclassification is a question about `ctypes-foreign` (which does ship
a compiled stub archive, unlike Python's ctypes), and it is a project
question rather than a pipeline one. Tracked in
[`../../project/issues.md`](../../project/issues.md) §1.

## 9. Code and tests

| what | where |
| --- | --- |
| the pass | `project/canary_project_analysis.ml` |
| named in the pipeline | `main/canary_pipeline.ml` — `analysed_of`, `json_analyse` |
| the chain filter | `action/canary_enumerate.ml` — `applicable_chains`, `chain_applicable` |
| the join | `project/canary_project_analysis.ml` — `touches_of`, `touches`, `produced_at`, `producers_of` |
| the dump | `canary emit <p> --stage analyse [--json]` |

Tests: `checks.applicability_reads_the_declaration` (pass 2's answer is
the declaration's, not the language default's),
`checks.index_speaks_each_action_language` (the 2026-09-15 instance),
`analysis.touches_joins_actions_to_declarations` (the join is total, a
probe produces nothing, a lib has several producers),
`mechanism.dynamic_binding_has_no_build_chain` (the `build_binding`
half of `chain_applicable`).

## 10. What is NOT here

- **Firing** — [pass 6](stage6_realize_steps.md). It needs a world.
- **What a claim SAYS** — [`../agreement/`](../agreement/README.md).
  This pass decides only whether the project can carry it.
- **Which worlds exist** — [pass 3](stage3_enumerate_worlds.md). Pass 2
  is world-free by definition.

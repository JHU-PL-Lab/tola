# Where agreements come from

**Kind: theory.** Why there is anything to check at all, what an agreement
*is* in terms of the actions that build software, and a procedure for finding
the next one. Paper material; the engineering view is
[`registry.md`](registry.md), the concrete records are
[`catalogue.md`](catalogue.md).

This document does not describe what Canary runs. It describes the thing
Canary is an implementation of, and it is written so that a reader who never
sees the code can tell whether the implementation is looking in the right
places.

## 1. Nothing to check, in an ideal world

Take a project where every file has exactly one copy and every artifact is
rebuilt from source in dependency order. The header the library was compiled
against *is* the header on disk. The binding was compiled against *that*
library. The application was compiled against *that* binding. Nothing can
disagree, and there is nothing for a checking tool to do — the build already
did it.

Real worlds are not like that, for reasons that have nothing to do with
carelessness. A library arrives prebuilt from a distribution. A binding
arrives from a language package manager that compiled it, months ago, on
another machine, against a library nobody here has. Headers come from a
`-dev` package whose version is chosen by a solver. Each of these is a
reasonable thing to do, and each one replaces a file that a build *produced*
with a file that merely *resembles* it.

**Checking exists because artifacts are recombined across the boundaries of
the builds that made them.**

## 2. What an action establishes

Model a build step as a function

```text
A : I₁ × … × Iₙ  →  O
```

Its implementation — a compiler, a linker, an archiver — embodies a relation
`R_A ⊆ I₁ × … × Iₙ`: the input tuples its rules accept. A C compiler rejects a
call that disagrees with a declaration; a linker rejects an undefined
reference. These rejections *are* `R_A`.

> **Running `A` on a tuple is a witness that the tuple is in `R_A`. Nothing
> else is.**

That witness is the full-information agreement of §5: at the moment the action
ran, the relation held over the actual files, checked by the actual tool, with
every input in hand.

Then the tuple is thrown away. What is kept is `O`, which carries the implicit
fact *some tuple in `R_A` produced me* without carrying the tuple. What
survives of the inputs is a **projection**: exported symbol names, a recorded
identity, version tags, sometimes debug information. Everything else — the
source, the declarations, the options — is gone.

## 3. What a check is

Recombination takes an `O` produced from tuple `t` and pairs it with an input
drawn from a different tuple `t′`. The hybrid may or may not be in `R_A`, and
`A` cannot be re-run to find out: the sources are gone, and in the next step
the output is an *input* (a `.so` is produced by the linker and consumed by the
next link).

So the question a checking tool faces is: **decide membership in `R_A` from
the projections that survived.** Hence:

> An **agreement** is a necessary condition for membership in some action's
> input relation, decidable from the artifacts' surviving evidence.

Three consequences, and they are the ones the catalogue keeps running into:

- **Necessary, not sufficient.** A pass cannot mean "compatible"; it means no
  counterexample within one projection. That is not a caveat about
  immaturity — it follows from the definition.
- **The agreement is rooted where the action ran, and detected later.** The
  pairing `(lib₁.so, v₂.h)` may compile perfectly at `build_binding`; it is
  wrong because no `compile_c` ever ran on `(v₂.h, …) → lib₁.so`. The action
  that owns the claim and the action where evidence is available are different
  actions.
- **One edge carries several agreements**, one per surviving projection, and
  each agreement admits several methods of observing it. Three levels:

```text
edge        (action, input → output)
  agreement   one per projection of the input that survives in the output
    method      one per way of observing it (read the artifact, run a tool, …)
```

## 4. Two kinds of loss

The information lost at an action divides in two, and the halves behave
differently enough to be worth separating.

|              | what is lost                       | remedy                                                       | ceiling                                                                                      |
| ------------ | ---------------------------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| **Identity** | *which* tuple produced this output | record it — hash, build id, soname, version tag, package pin | can be made **complete**: with enough recorded, you compare identities and need no inference |
| **Relation** | *what `R_A` required* of the tuple | re-implement a fragment of the tool's rule                   | only ever **partial**: completeness means re-implementing the compiler                       |

The distinction predicts which gaps are worth what. An identity gap is a
*recording* problem — it closes by writing more down, and it closes exactly. A
relation gap is a *checker* problem — it closes by degrees and never fully.
When a proposal is stuck, it is usually worth asking which of the two it is;
`denotation_stable_across_worlds` is stuck because it needs an identity
criterion, not a better comparator.

## 5. The full-information agreements, action by action

For each action in Canary's catalogue: the relation the real tool established
when it ran, what survives of it afterwards, and what post-fact checking can
recover. Status is as of 2026-09-12 — see [`landing.md`](landing.md) for what
a real run has actually decided.

### 5.1 `fetch_source` — a resolver picks a tree

|                 |                                                                                                                                                                                          |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | git, or a package manager                                                                                                                                                                |
| **Established** | this tree is what that ref names, at that moment                                                                                                                                         |
| **Survives**    | the tree; the commit, *if* recorded                                                                                                                                                      |
| **Loss**        | identity                                                                                                                                                                                 |
| **Post-fact**   | re-resolve the ref and compare. Canary does this (`source_fetch_pinned_ref_check_post`), and because it is identity, it is **exact** — the rare case where checking is not approximation |

### 5.2 `configure` — a build system fixes a configuration

|                 |                                                                                                                                                                                                                                           |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | cmake, autoconf                                                                                                                                                                                                                           |
| **Established** | this build tree is configured for *these* sources, *this* toolchain, *these* options                                                                                                                                                      |
| **Survives**    | the build tree and its cache; the options, in a form nobody reads back                                                                                                                                                                    |
| **Loss**        | identity (which sources) and relation (which options the result assumes)                                                                                                                                                                  |
| **Post-fact**   | **not checked.** A build tree configured for source A and reused with source B is a recombination Canary does not currently look at. Its analogue is well known in practice — a stale `CMakeCache.txt` — and there is no agreement for it |

### 5.3 `build_lib` — the compiler and linker

The central action, and the one with the richest surviving projection.

|                 |                                                                                                                                                                                                                                                                     |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | a C compiler, then a linker                                                                                                                                                                                                                                         |
| **Established** | (a) every call agrees with a visible declaration; (b) every referenced symbol is defined; (c) the output records the requested identity and the requested dependency list                                                                                           |
| **Survives**    | exported symbol names; version tags; the recorded soname; `NEEDED`; debug information, sometimes                                                                                                                                                                    |
| **Loss**        | relation, mostly — the declarations are gone and the definitions are compiled                                                                                                                                                                                       |
| **Post-fact**   | *names*: `declared_symbols_exported`. *types*: the DWARF comparison (registry §2.2, proposed) — the only route back to (a), and it depends on debug information being present. *identity of the output*: `soname_matches_declaration`, `declared_versions_exported` |

One projection is unclaimed: symbols the library exports that appear in
**neither** the headers nor this project's declaration. They came from
somewhere — a statically linked archive, a vendored copy — and nothing in the
catalogue says so. Tiny already produces the fault (`symbol_orphan`) and the
tracker already records that no agreement claims it.

### 5.4 `install_lib` — staging

|                 |                                                                                                                                                                                                                                                                                                                                                                         |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | `cmake --install` and friends                                                                                                                                                                                                                                                                                                                                           |
| **Established** | the staged tree is a relocation of the build tree preserving the declared interface                                                                                                                                                                                                                                                                                     |
| **Survives**    | **both sides** — the build tree and the staged tree exist at once                                                                                                                                                                                                                                                                                                       |
| **Loss**        | almost none, while the run lasts                                                                                                                                                                                                                                                                                                                                        |
| **Post-fact**   | comparison is nearly complete *because nothing was lost yet*. Canary compares symbol counts, soname, RPATH/RUNPATH and NEEDED across the two (`install_diff_note`); the fuller model is [`staged_parity.md`](../staged_parity.md). This is the one action where a checker can be almost as strong as the tool, and it is worth noticing why: the inputs are still there |

### 5.5 `build_binding` — the foreign-call boundary

|                 |                                                                                                                                                                                                                                         |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | the host compiler for the stubs, plus the language's archiver                                                                                                                                                                           |
| **Established** | the stub's `external` declarations agree with the header; the stub objects' undefined references name things the library is expected to define; the archive is internally consistent                                                    |
| **Survives**    | the stub archive's undefined references; the installed interface; for a shared-object binding, `NEEDED` and version requirements                                                                                                        |
| **Loss**        | relation                                                                                                                                                                                                                                |
| **Post-fact**   | `signatures_agree` (header ↔ stub types, from source scanning — the compiler's rule, re-implemented shallowly); `required_symbols_exported` (stub references ⊆ library exports — the linker's rule, re-implemented exactly *for names*) |

### 5.6 `fetch_binding` — the load-bearing one

|                 |                                                                                                                                    |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | opam, pip — and, earlier and elsewhere, a `build_binding` nobody here witnessed                                                    |
| **Established** | *in another world.* Some `build_binding` ran against some library, on some machine, at some version                                |
| **Survives**    | the installed artifacts and the package metadata — and **none of the other world's inputs**                                        |
| **Loss**        | both, maximally                                                                                                                    |
| **Post-fact**   | everything the catalogue has. This is where recombination actually happens in practice, and where the checks are most load-bearing |

Worth stating plainly, because it reorders priorities: in a world that builds
its library and fetches its binding, **the library↔binding edge is the only
one no toolchain ever established.** The source↔library edge was established
here; the binding↔application edge is established by the compiler that builds
the probe. One edge out of three, and it is the one whose checks are hardest
to supply evidence for.

### 5.7 `pack` / `publish` — packaging

|                 |                                                                                                                      |
| --------------- | -------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | opam, a wheel builder, a distribution's packaging                                                                    |
| **Established** | the package contains the artifacts the recipe named                                                                  |
| **Survives**    | the package                                                                                                          |
| **Loss**        | identity (which build tree) and relation (what the recipe required)                                                  |
| **Post-fact**   | completeness against a declared file list; Canary's staged-file checks are hand-listed, and the general form is open |

### 5.8 `build_app` — the consumer

|                 |                                                                                                                                                                                                                                                                          |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Tool**        | the language's compiler and linker                                                                                                                                                                                                                                       |
| **Established** | every name the application uses resolves on the binding's surface; the link succeeds                                                                                                                                                                                     |
| **Survives**    | the executable; its recorded dependencies                                                                                                                                                                                                                                |
| **Loss**        | relation                                                                                                                                                                                                                                                                 |
| **Post-fact**   | the application's used names ⊆ the binding's surface. Canary approximates this with a hand-written watchlist rather than the application's actual uses — an approximation worth revisiting, since the requirement could be derived from the source the way the stub's is |

### 5.9 `probe_*` — execution

|                 |                                                                                                                                                                                                                                                                                                                                                         |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | the dynamic loader, then the program                                                                                                                                                                                                                                                                                                                    |
| **Established** | every recorded dependency resolved to some object; every symbol bound to some definition; the program produced this output                                                                                                                                                                                                                              |
| **Survives**    | the output and the exit status. The *resolutions* — which object, which definition — survive only with instrumentation                                                                                                                                                                                                                                  |
| **Loss**        | relation, and identity of what was actually selected                                                                                                                                                                                                                                                                                                    |
| **Post-fact**   | behavioural expectations (`behavior_matches`, unimplemented — the expected values live inside the probe). The resolution half is where `dependencies_provided` stops and where `interposition_binds_build_target` and `denotation_stable_across_worlds` would begin; all three need a recorded resolution trace, which is the identity half of this row |

### 5.10 Reading the table

Three patterns fall out, and none was designed in:

1. **The strongest checks are where the least was lost.** `install_lib` can be
   checked nearly completely because both sides are still present.
   `fetch_binding` can be checked least well because nothing but the artifact
   survived.
2. **Identity rows close; relation rows converge.** `fetch_source` is *done* —
   re-resolving the ref settles it. `build_lib`'s type agreement will never be
   done, only deepened.
3. **The action that owns a claim is rarely the action with the evidence.**
   `build_lib` roots the header↔library agreement; the evidence for it is read
   at `build_binding` and `probe_binding`. Any implementation needs to keep
   those two apart, and Canary's does.

## 6. The procedure

The table is not only a summary — it is how to find the next agreement. For
each action, for each input, ask:

1. **Which earlier action produced this input?** That action's `R` is the
   relation at risk.
2. **Which projection of the input survives into the artifact I hold?** That
   projection bounds what any check can see.
3. **Is the pairing witnessed?** If the input and the artifact came from the
   same run, the tool already checked it and there is nothing to add. If they
   came from different runs, the pairing is asserted and unchecked.
4. **Is the loss identity or relation?** Identity gaps close by recording;
   relation gaps close by re-implementing a fragment of the rule.
5. **State the falsifier.** If you cannot say what observation would refute
   the claim, it is not yet an agreement.

Two checks that the procedure is sound before trusting it on new ground: run
on Canary's own chain, it re-derives the application-uses-⊆-binding-surface
claim that the watchlist currently approximates, and it re-finds the
unclaimed orphan-export projection at `build_lib` that the tracker already
records as a hole. A procedure that re-finds known holes from first
principles is one worth pointing at unknown ones.

## 7. What this does not explain

Two things in the catalogue are not per-edge and do not fall out of this
model:

- **Set properties.** `no_duplicate_implementation` is about the whole
  resolved set, not about any one pairing. Nothing in §2 speaks about sets.
- **Cross-world properties.** `denotation_stable_across_worlds` compares two
  worlds. There is no single action whose relation it recovers; it is a claim
  about two runs of the same action, which this model has no vocabulary for.

Both are real and both are in the registry as proposals. The honest statement
is that the per-action frame covers most of the catalogue and that these sit
outside it — which is itself worth knowing, because it says they will not be
found by the procedure in §6 and need their own reasoning.

### 7.1 And one the procedure finds that is NOT an agreement

§6 run over `fetch_source` produces "the source tree is the ref the project
declared" (§5.1), and it looks like a textbook identity gap: recordable,
cheap, closes exactly. It is in the registry as the proposal
`source_is_declared_ref`.

It is the wrong category (2026-09-15, user). An agreement is a claim about
**the project's artifacts** — what the library exports, what the stub
requires, what the package contains. "Is the tree at the commit we said" is a
claim about **whether canary realized the world it claims to be testing**.
That is harness self-verification, and canary already has a vocabulary for
it: the world assertions (`Canary_world.Log_names`, `Opam_pin`,
`pin_check_post`, z3's `SYSTEM LIB MISSING`) which assert that a scenario's
declared world was actually established.

The distinction matters because the two fail differently and are read by
different people. A violated agreement is a finding **about the software**;
a failed world assertion means **this run tested something other than what it
says**, and every verdict in it is suspect. Filing the second as the first
would put "our harness misconfigured itself" on the same list as "this
library dropped a symbol".

So §6 needs a filter it does not currently state: *whose* rule is being
recovered. `ag_rooted_in` already asks that question of every registered
agreement — and for §5.1 the honest answer is "canary's own", which is
exactly the signal that it belongs elsewhere.

Left in the registry as a proposal rather than deleted, with this note,
because the CHECK is worth having and the reasoning about where it lives is
the part that was missing.

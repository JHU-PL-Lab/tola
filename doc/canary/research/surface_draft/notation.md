# Notation — PL scaffold (parked)

### 1. Artifact records

An **artifact** is anything that can be identified, versioned, and inspected.
Each artifact carries a **record**: a typed set of observable properties
extracted by lightweight static inspection.

```
Kind a  ∋  Source | Native | Binding(L) | Package(PM) | App

Record : Kind → Type
Record Source      = { version : V; files : Path list; api : Surface }
Record Native      = { symbols : Symbol set; versioned : Symbol → V;
                       elf : { soname : V option; needed : V list; … } }
Record Binding(L)  = { modules : Module set; requires : Symbol set;
                       watchlist : Name list }
Record Package(PM) = { name : Name; version : V; provides : Record list }
Record App         = { imports : Module list; link_deps : Name list }
```

Records are **observational**: they capture what `nm`, `readelf`,
`ocamlobjinfo`, and `dir()` can see without executing the artifact.

> Moved here from `surface.md` on 2026-06-04 because notation
> maintenance is deprioritised until the theory settles. Reinstate
> in the manuscript (likely inside §2 SS) once the rule catalogue
> and trace definitions are stable enough to deserve formal
> labels. Pairs with the conceptual "Backbone" section still
> floating in `surface.md`.

A light PL scaffold for naming concrete instances precisely. The
backbone uses everyday vocabulary; this section pins down the
shapes.

- **Artifact kinds**: `k ∈ K = {Source, Lib, Binding, App, …}`.
- **World** `W = (A_k)_{k ∈ K}`: one artifact per kind, drawn
  from per-kind candidate sets `𝒜_k`.
- **Rule** `r : (A_k, A_{k'}) → {ok, viol}`: a predicate over a
  pair of surfaces from a world. Write `W ⊨ r` for "holds,"
  `W ⊭ r` for "violates."
- **Concrete trace.** From baseline `W₀` with `W₀ ⊨ r` for all
  rules, a perturbation `μ` of one surface yields the pair
  `(W₀, μ(W₀))`, witnessing `μ(W₀) ⊭ r` for the target rule.
- **Abstract trace.** Given per-kind stores `𝒮_k ⊆ 𝒜_k`, a trace
  is any `W ∈ Π_k 𝒮_k`; the verdict per rule is `W ⊨ r` or
  `W ⊭ r`.

A rule is **exposed** if some trace witnesses `⊭ r`. The
methodological claim, stated formally: for every `r` in the
catalogue, there exists both a concrete trace `(W₀, μ(W₀))` with
`μ(W₀) ⊭ r` and an abstract trace `W ∈ Π_k 𝒮_k` with `W ⊭ r`.

## Backbone section — verbose original (parked 2026-06-11 from surface.md L124-168)

A **rule** says what counts as agreement between two surfaces
(the `c1..c7` catalogue). A **world** is a configuration of
artifacts; a rule is either satisfied or violated in a given
world. A **trace** is an observed verdict — the rule's status on
a particular world.

Two trace shapes do complementary work:

- **Concrete trace.** A specific world we construct by hand:
  tiny + a controlled perturbation. Each rule has at least one
  concrete trace witnessing a violation — a single, reproducible
  failure.
- **Abstract trace.** A world drawn from per-kind candidate sets:
  one artifact per kind, sourced independently. Canary's variant
  matrix is a structured walk over the abstract-trace space; the
  same shape applies to natural producers (opam / pip / apt).

### More analogy: traces

Continueing the PL-analogy, the tiny scenarios are **concrete traces**
 for both correct and incorrect artifacts.

The spine has a clean PL parallel: artifact ↔ *expression*,
surface ↔ *type*, contract ↔ *run-time invariant / assertion* —
positioning surface theory as "a type system for binding
interfaces" (hook for §6.6 calculus sketch). A complementary
internal vocabulary names **rules** (the catalogue — agreements
between surfaces) and the **traces** that observe
them in particular **worlds** (configurations of artifacts):
**concrete traces** are tiny + a controlled perturbation (single
reproducible witness, §4), **abstract traces** are worlds drawn
from per-kind stores (independent-producer combinations, §5); §7
covers how each shape is mechanically produced. The formal
scaffold (rule / world / trace definitions) is parked in
[`surface_draft/notation.md`](surface_draft/notation.md) until
the theory settles enough to need it.

- **Worlds and traces.** A configuration of artifacts is a world;
  a trace is an observed verdict — either the rule holds or it
  doesn't. Tiny gives controlled worlds we hand-build; canary
  scales to worlds we don't control, drawn from natural producers.
- **Producer-agnostic by design.** The same rules and the same
  framework apply to synthetic worlds (tiny) and natural worlds
  (opam / pip / apt).

In PL terms, **rules** are inference rules / property statements
and **traces** are executions — concrete traces are single runs
(tiny + a perturbation), abstract traces are the execution space
drawn from per-kind stores. This complements §1.5's spine analogy:
the spine names *what is agreed upon* (artifact / surface /
contract); the backbone names *how agreement is tested* (rules
observed via traces in worlds).

A rule is robust when both trace shapes expose it. Concrete
traces give **depth** — controlled, reproducible witnesses;
abstract traces give **breadth** — configurations that arise from
independent producers, beyond what hand-construction can reach.

This maps the §2–§4 arc: §2 names the rules; §3 covers the
concrete-trace witness (tiny); §4 covers the abstract-trace
framework (canary), including a validation step against tiny's
concrete traces along the way. How each shape is mechanically
produced is **§6 Implementation**.

The PL notation scaffold (formal rule / world / trace definitions)
is parked in [`surface_draft/notation.md`](surface_draft/notation.md)
until the theory settles enough to need it.


## Stray scratch (from purged sections, 2026-06-05 to 2026-06-11)

Free-form marginalia rescued before purging the duplicated
*Project-wide planning grid* and *§2 SS restructure plan*
sections (those are now landed in `surface.md` §1.5 / §2.1–§2.6).
Kept here as content seeds; not actionable.

- *tiny: one good set of artifacts, plus lots of mutations…
  concrete traces (….) retire..*
- *tiny-dyn*
- *canary: src store × lib store*
- *invariant; standards; contract : sth written* — vocabulary
  exploration on the agreement word.

---


---

not used artifacts

--

**Sn.5 — OCaml stub `.a` inspected** (s5 binding_lib, semantic).

```
$ nm tiny_stubs.a | grep -E 'tiny_|caml_tiny'
                U tiny_offset
                U tiny_sum
T caml_tiny_sum
T caml_tiny_get_offset
```

**Sn.6 — Runtime probe** (s6 runtime_trace, semantic).

```
input:    set tiny_offset = 42
          call tiny_sum(2, 3)
expected: 47          (i.e. 2 + 3 + 42)
```

### 2.9 Surface Satisfaction

A surface is **satisfied** for a set of contracts `𝓒` if every
contract in `𝓒`, together with every refinement (e.g. SymbolVersion
refining Symbol), passes:

```
Satisfies(r_provider, r_consumer, 𝓒) ⇔
  ∀c ∈ 𝓒. ∀c' ⊑ c. check_c'(r_provider, r_consumer) = Pass
```

The check is conjunctive: contracts can be parallel (e.g. Symbol and
ABI are orthogonal) or refinement-related (SymbolVersion ⊑ Symbol);
the satisfaction predicate doesn't care, it just requires all of
them.
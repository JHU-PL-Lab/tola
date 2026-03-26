# Expression Sharing and DAG Enumeration — Background Notes

Off-topic reference notes from the job space discussion.

## Why derivatives grow: the sharing problem

The classic example: repeated differentiation of `x^n` in expanded form.

Consider `f(x) = (x+1)^2 = x^2 + 2x + 1`. As a tree:

```
    *
   / \
  +   +
 / \ / \
x  1 x  1
```

The derivative via the product rule duplicates both subtrees:
`f'(x) = (x+1)'*(x+1) + (x+1)*(x+1)'`. The expression doubles in size
even though the result simplifies to `2(x+1)`.

With **sharing** (DAG / let-binding):

```
let a = x + 1 in a * a
```

Derivative: `let a = x + 1 in let a' = 1 in a' * a + a * a'` — linear
growth. This is exactly **automatic differentiation** (AD): forward-mode
AD is differentiation on the DAG, avoiding the exponential blowup of
symbolic differentiation on trees.

The general principle: **trees duplicate shared subexpressions; DAGs
preserve sharing**. Any operation that traverses a tree and produces
results proportional to subtree size (differentiation, substitution,
evaluation with memoization) benefits from the DAG representation.

Our job space has the same structure: `lib@spm` is shared between T2
and T5, but the expression model duplicates `fetch(spm)` in each.

## Canonical tools for structured enumeration

### Term enumeration (our current approach)

Given typed operations with fixed signatures, enumerate all well-typed
terms up to bounded depth. This is well-studied:

- **Catalan numbers**: count full binary trees of depth n (our expressions
  are similar but with typed constraints)
- **Species theory** (Joyal): combinatorial framework for counting
  structured objects — generating functions over types
- **Type-directed synthesis** (program synthesis): enumerate all programs
  of a given type, used in tools like Myth, Synquid, and Leon

For our problem the space is small enough (bounded by the sort hierarchy
depth of 4) that brute-force enumeration suffices.

### Graph grammars

**Hyperedge replacement grammars** (HRG): generate graphs by rewriting
hyperedges. Each production replaces a labeled hyperedge with a subgraph.
The language of an HRG is a set of graphs.

Relevant when: the patterns you want to enumerate are themselves graphs
(not trees). Our job patterns are DAGs, so HRGs could describe the space.
But our DAGs are small and structured enough that this is overkill.

Key reference: Rozenberg (ed.), *Handbook of Graph Grammars*, 1997.

### Petri nets

Model concurrent systems as bipartite graphs of **places** (holding
tokens = artifacts) and **transitions** (consuming/producing tokens =
operations). A **marking** is a distribution of tokens across places.
**Reachability analysis** enumerates all markings reachable from an
initial marking.

Maps to our problem:
- Places: `Source`, `Lib@bt`, `Lib@spm`, `Binding@bt`, `Package@lpm`, ...
- Transitions: `compile_lib` (consumes Source token, produces Lib@bt
  token), `fetch(spm)` (produces Lib@spm token), etc.
- Initial marking: one token in `Source`
- Reachability question: which markings include a `Result` token?

Each reachable marking with a `Result` token corresponds to a valid job.
The **reachability graph** of the Petri net is exactly the enumeration of
all valid jobs.

Advantages: naturally handles concurrency (two independent fetches in T8),
resource consumption (a Lib token is consumed by compile_binding), and
multi-input transitions. The formalism has mature analysis tools
(coverability, boundedness, liveness).

Key reference: Murata, "Petri Nets: Properties, Analysis and
Applications", Proceedings of the IEEE, 1989.

### Dataflow graphs / Kahn process networks

Used in compiler IRs (SSA form), signal processing, and hardware design.
Each node is an operation; edges carry typed values. **Design space
exploration** in hardware synthesis enumerates all valid dataflow graphs
for a given specification — directly analogous to our problem.

### String diagrams (monoidal categories)

Category-theoretic notation for composing morphisms with multiple inputs
and outputs. Operations are boxes; wires are typed connections. Composition
is horizontal (sequential) and vertical (parallel/tensor).

Our operations map directly:
- `compile_binding : Source ⊗ Lib → Binding` (tensor product for
  multi-input)
- `probe : Binding ⊕ Package → Result` (coproduct for sum input)

String diagrams are the "honest" notation for DAGs of typed operations —
they make sharing, fan-out, and multi-input explicit without the tree
bias of term notation.

## Summary

| Tool                 | Strengths for our problem           | Overkill? |
| -------------------- | ----------------------------------- | --------- |
| Term enumeration     | Simple, bounded depth, sufficient   | No        |
| Graph grammars (HRG) | Generate graph patterns             | Yes       |
| Petri nets           | Multi-input, concurrency, resources | Maybe     |
| String diagrams      | Honest DAG notation                 | Notation  |

For our current scale (4 sorts, 5 operations, 9 traces), term enumeration
with the tree-to-DAG quotient is the right level. If the space grows
(multi-lib, downstream deps), Petri nets would be the natural next tool.

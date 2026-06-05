# Notation — PL scaffold (parked)

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

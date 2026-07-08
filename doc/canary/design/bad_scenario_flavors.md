# Two flavors of bad scenarios

Reference for the *next* task after Task 1.6. Captures a
structural distinction between two kinds of failure the
tiny witness covers — and where each kind needs work for
canary to serve as a real-world bug-categorisation
foundation.

## The distinction

A bad scenario has to be one of two shapes:

| | Flavor 1: defect *in* one artifact | Flavor 2: mismatch *between* two artifacts |
|---|---|---|
| Locus | A single artifact is missing / adding a field | Two artifacts, each individually well-formed, don't fit at their meeting point |
| Contracts today | c1 (missing/orphan symbol), c2 (missing watchlist entry), c3 (probe-observable behaviour) | c4 (SONAME), c5 (versioned symbols), c6 (type signature), c7 (repack), c8 (faithfulness — dormant) |
| Tiny examples | symbol_missing, symbol_orphan, api_complete, api_complete_python, behavior_silent | abi_soname_bump, symbol_version_floor, header_arity_bump, api_repack, api_repack_python |
| Detection mechanism | Set inclusion / assertion in probe | Cross-artifact comparator |
| Enumerated by | Field enumeration of the artifact | Contract catalogue (pairs × contract kind) |

Naming (informal): flavor 1 = **artifact-local defect**;
flavor 2 = **cross-artifact mismatch**.

## Flavor 1 — reuse across Good scenarios

Flavor 1 perturbations follow a small template family:

- *drop a field* — remove a symbol from lib source; remove a
  `val` from mli; remove an attribute from `__init__.py`
- *add an orphan* — introduce a stub referencing a symbol
  the lib never had (c1's orphan direction)
- *swap behaviour* — same signature, wrong result (c3)

Each template instantiates at any artifact layer. The
factory's `derive_scenarios` enumeration already surfaces
these as `(Good × related-artifact × applicable-kind)` cells
in `tiny-scenarios list`. Today 5 cells are filled, 15 are
empty — the empty ones are candidate flavor-1 slots.

**Reuse pattern in the code**:

- Same `(perturbation kind, target artifact)` shape reused
  across different Good scenarios by picking different
  cells.
- Same perturbed store consumed as input by *downstream*
  Good scenarios (a lib missing symbol X cascades into
  build_binding's build failure, into build_app_with_binding's
  probe failure, and so on).

**The reuse gap today**: perturbations are hand-written
patch files (`c/src/tiny.c`) naming specific symbols.
Parametric perturbations — "drop symbol `<X>` from artifact
`<A>`" as data, generating the patch on demand — is the
last unresolved axis. SSOT §9.3 Task 1.6 backlog item 2
(`tiny_recipe synthesis from an abstract cell`) is this
work.

Once parametric, filling the 15 empty cells becomes
mechanical.

## Flavor 2 — discovery completeness

Flavor 2 is bounded by our **contract catalogue** (c1..c8).
Adding a new failure kind means adding a contract, adding
its inputs shape to `compat_inputs_of_contract`, and (usually)
adding a corresponding Bs entry to tiny.

**Where the current catalogue comes from**: reverse-
engineered from a few specific bug shapes:
- Python's z3-solver / llvmlite version-mismatch bugs → c1
- opam's `llvm.dev-shared` vs `llvm.19-shared` split → c4/c5
- API-drift regressions in bindings crossing major versions → c2

Plus theory-driven contracts:
- c6 cmp_type — decidable-but-conservative subtyping
- c7 cmp_api_repack — soundness of a repacking layer
- c8 cmp_api_faithful — completeness of a repack (dormant)

**No empirical proof of completeness.** The catalogue
covers what we've seen; new real-world failure modes could
require new contracts.

## Toward "trying to be complete to real-world"

The goal user framed 2026-07-08: **tiny as the simplest
complete/regression collection** — a foundation for
categorising real-world binding failures. To move toward it:

**Failure kinds the current catalogue doesn't cover**:

1. **Transitive dependency compat**. glibc version floor,
   libstdc++ ABI, ELF `NEEDED` chains beyond one hop. c4
   stops at direct soname; a proper transitive check would
   walk the NEEDED graph.

2. **Runtime-only invariants**. Thread-safety, memory model,
   initialization order (C++ static constructors), signal
   safety. c3 covers assertion violations in single-thread
   deterministic probes; concurrent / load-dependent failures
   are outside.

3. **Package-management-layer mismatches**. Same lib supplied
   by opam / apt / pip may have divergent build flags,
   patches, or ABI. Motivates PyTorch as a Tier-1 canary
   target (see `design/new_project.md`).

4. **Platform-specific ABI**. macOS Mach-O `install_name` vs
   Linux ELF `SONAME`; Windows DLL exports; C++ symbol
   mangling variants. c4 assumes ELF SONAME today.

5. **Config-time perturbations**. cmake `-DHAVE_FOO=0` vs
   `-DHAVE_FOO=1` at build time exposes different symbol
   sets. Not really a *contract* — a store-synthesis
   parameter that changes what artifact is even built. Might
   be modelled as a perturbation flavour parallel to
   `Patch` / `Soname_bump`.

6. **Behavioural divergence under upgrades**. Same C API,
   same soname, semantically-changed result. Covered by c3
   in principle; needs a probe library richer than tiny's
   `assert x == 5` to catch subtle behavioural drift.

## Path forward (near-future task)

Sketch, not committed:

1. **Cull open-source bug trackers** for failure kinds not
   covered by c1..c8. Debian bugs on soname bumps; PyPI
   issues on ABI mismatches; opam issues on version
   constraint violations. Publish a table of kinds keyed by
   real bugs.
2. **Propose new c_i** per uncovered kind. Or extend an
   existing contract's scope (e.g., c4 → transitive c4).
3. **Add a Bs entry to tiny** for each newly-added contract.
   The mechanical loop from §9.3 Task 1.6 continues:
   `compat_inputs_of_contract` gains a case; tiny gains a
   fixture; regression coverage grows.
4. **Contract completeness** is validated *empirically* — "we
   haven't seen a wild failure that our contracts don't
   explain." This is the same shape as compiler-warning
   completeness or test-coverage completeness; no proof,
   only accumulating evidence.

## Interaction with the manuscript

The 8-contract inventory in
[`doc/canary/research/surface.md`](../research/surface.md) is
a snapshot. This document argues *why* we should expect the
inventory to grow — and what shape that growth will take
(each new contract is a new comparator between two artifact
surfaces). Neither the manuscript nor this doc claims c1..c8
is complete.

## Not doing yet

- New contracts (c9, c10, …) — awaiting the cull.
- Multi-contract aggregation across Expect_compat_failure
  and Expect_failure shapes — awaiting a Bs entry that
  needs it.
- Coverage tag on `tiny-scenarios list` distinguishing
  flavor 1 vs flavor 2 cells — cheap; ship when useful.
- Formal soundness claim for the 8-contract catalogue —
  research question.

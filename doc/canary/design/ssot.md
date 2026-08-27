# SSOT — retired 2026-08-27

**Kind: reference (stub).** This file was the ID dictionary bridging
manuscript ↔ code. It is retired: it was a *third copy* of facts that
each had an owner elsewhere, so every row drifted at whatever rate its
two real ends were edited — and the measurement that ended it found the
drift was this file's own (its `Sf` table lagged behind both the draft
and `canary_contract_registry.ml`, which already agreed).

**The stub stays because the source cites it in 33 places.** Those
citations name a section; this table says where that section went.
Repointing them is mechanical and unblocked.

| you were sent here for | it now lives in |
| --- | --- |
| §4.2, §4.2.1–§4.2.5 — enumeration, the provision × version model, the artifact & axis model, the mutation-agnostic spec | [`enumeration/`](enumeration/) — one doc per pass; start at [`enumeration/README.md`](enumeration/README.md) |
| §6.1 — term ↔ code (project / scenario / runner_spec / step / action) | [`enumeration/stage0_naming.md`](enumeration/stage0_naming.md) § *Term ↔ code* |
| §6.5 — the action catalogue | `src/canary/action/canary_action.ml` + [`enumeration/stage5_realize_steps.md`](enumeration/stage5_realize_steps.md) |
| §6.6 — `runner_spec` | [`enumeration/stage5_realize_steps.md`](enumeration/stage5_realize_steps.md) |
| §1 `Ar.X`, §2 `Sf.X`, §3 `Ag.X`, §4.1 concrete good scenarios, §5 `Bs.N`, §7 | [`../research/surface_draft/ids.md`](../research/surface_draft/ids.md) — paper-side material, statuses to be read as history |
| §8 — downstream usage in `draft.md` | dropped; the draft carries its own ids |

**Do not restore this file.** If the manuscript and the code need to
agree on an id, the fix is a generated fragment plus a check that
diffs it — not a third hand-maintained copy. The `Ag.X` ↔ `C1..C8`
mapping is the one bridge worth generating, and
`canary_contract_registry.ml` already holds the data to generate it.

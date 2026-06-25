### Vocabulary deliberation: contract / invariant / agreement (parked 2026-06-11)

User flagged 2026-06-11 that **contract** carries an "explicit
written" connotation that fits c1 / c2 / c4 / c5 / c6 but stretches
for c3 Behavior (implicit, runtime-determined), c7 API-repacking
(intent-only), and the hidden-deps extension target (§3.5 — no
party writes it down). The asymmetry is real.

#### Options surveyed

| Term          | Fits explicit | Fits implicit | Two-party flavor | "Can be broken" verb             |
| ------------- | ------------- | ------------- | ---------------- | -------------------------------- |
| **Contract**  | ✓             | ✗             | ✓✓               | ✓ (break a contract)             |
| **Invariant** | ✓             | ✓             | △                | ✗ (invariants hold)              |
| **Property**  | ✓             | ✓             | ✗                | △                                |
| **Agreement** | ✓             | ✓             | ✓✓               | ✓ (break agreement)              |
| **Rule**      | ✓             | ✓             | △                | ✓ — but reused for c-meta schema |

#### User's refining cut (the deciding point)

**"Agreement is more umbrella; invariant is principle-flavor.
One can break the agreement, while the invariant should already
hold."** The verb compatibility is what tips it: canary's whole
business is to *run scenarios that violate*. "Break the
agreement" reads naturally; "break the invariant" doesn't —
invariants are by definition the things that hold, so saying
they "break" undercuts the term.

This bumps **agreement** above **invariant** as the umbrella
candidate, and re-pins **contract** as a *subtype* (an
agreement-with-a-written-carrier).

#### Where this leaves things

Three live candidates:

- **(a) Full rename to "agreement"** as the umbrella term across
  §1.4 grid + §3.4 title + table + prose. Contract becomes a
  subtype label for the c-metas that have a written carrier.
- **(b) Keep "contract" with reframing** in §3.4: "an agreement
  pinning two surfaces — most are *explicit contracts* (written
  declarations); some are implicit." Lower churn; preserves the
  established vocabulary at the cost of mild dissonance for c3 /
  c7.
- **(c) Half-rename**: §3.4 title and the `Table —` label switch
  to "Agreement"; row labels and code-level vocabulary stay
  "contract" until a wider sync.

--

### Boundary vs surface — vocabulary unification (2026-06-12)

User's framing: **boundary = the objective reality** (the locus
where artifacts meet); **surface = what is detected** at that
boundary. Inspector bridges the two. Aligns naturally with the
syntactic / semantic split — semantic surfaces are what
inspectors extract at the boundary; syntactic surfaces are what
the developer declared about it.

Current manuscript mixes "boundary" in three senses (§3 SS prose
audit found three distinct uses):

- **(A) Artifact boundary** — the objective locus. *Load-bearing.*
  §3.1, §3.3 use this correctly.
- **(B) Native ↔ binding "boundary"** — the chasm between two
  *families* of artifacts, not one artifact's boundary. Currently
  in §3.4 ("the other five cross the native ↔ binding
  boundary"). Should rename to **"native ↔ binding divide"** or
  **"side"** or **"chasm"** — different *kind* of separation
  from (A).
- **(C) Engine boundary / harness-canary boundary** — implementation
  seam. §1.5, §5.5, §7.5. Lower priority — context disambiguates
  by §5 / §7 — but could rename to **"engine seam"** /
  **"engine interface"** for cleanliness.

When prose lands:

- Add a one-sentence definition in §3.1: *"By 'boundary' we mean
  the objective locus where one artifact meets another; a
  **surface** is what's detected at that boundary."* Before §3.2
  uses the term.
- Rename (B) — single occurrence in §3.4 bullet.
- Decide on (C) — likely leave alone unless §7 prose pass needs
  the disambiguation.

Surface uses appear to be already clean (noun = detected
properties; verb = "to come up" — distinct).
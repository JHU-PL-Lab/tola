# The artifact cache — caching what was MADE, not what was run

**Kind: proposal.** Nothing here is implemented. **Landed when** a step's cache key includes the identity of its INPUT artifacts, not only its own cmd/expectation fingerprint (`step_fingerprint`, `backend/canary_local_runner.ml`).

> 2026-08-19, opened by the user: "we need to design a good cache system
> for artifacts, so it can support to run even newly added actions."
> Design note, nothing implemented. The immediate motivation is that
> re-running a small project is cheap, so the cache should never be the
> reason a new action forces a rebuild.

## 1. What exists today, and its exact shape

**There used to be a SECOND cache, and it was deleted on 2026-09-16 so
that this proposal would not be built beside it** (user: *delete it or
gate it — do not build an artifact cache while it sits there*). The
global cache mapped `"<cache_project>:<step_tag>"` to a GitHub Actions
step conclusion, was filled by a `canary cache-sync` subcommand, and was
consulted by `run_step` before anything else. Four findings, the first
fatal:

1. **it could not hit,** and had not been able to since A5
   (2026-08-05). `cache-sync` wrote keys from the CI job specs, the only
   callers overriding `cache_project`; a local run left the default,
   which is the per-SCENARIO project name. Disjoint key spaces.
2. **it was unreachable**: `--cache` was parsed on `canary action` and
   threaded only into the tiny runner, so passing it to a registry
   project was silently ignored;
3. **it bypassed every gate** — the hit short-circuited above the warm
   gate, skipping the fingerprint, `check_post`, the switch and the
   platform;
4. **nothing fed it**: the default file never existed.

`step.cache_key` went with it, because a written-and-never-read key
field is exactly what this proposal's key would be mistaken for. Note
what the pair of them says about the design below: the global cache
answered *"did CI run a step with this name?"*, which is the question
this document argues is the wrong one.

What remains is one cache, and it is the sound one. It is a **step
marker cache**, not an artifact cache:

- each step writes `<step_dir>/<tag>.verdict_<variant>.ok`, whose line 1
  is the verdict flavor and line 2 a FINGERPRINT of the step's realized
  command + expectation form (`step_fingerprint`, marker v2, e2b4d27);
- a warm skip requires marker + fingerprint match + `check_post`;
- the key is `(project, variant_id, step tag)` — where `variant_id` is
  the scenario dir name, i.e. the assignment's placements.

It answers exactly one question: *did THIS step, as currently specified,
already run in THIS scenario?* Three things follow, and all three bit us
on 2026-08-19 (see `project/landing.md` §4):

1. **It says nothing about the artifact.** A step can re-run and produce
   nothing (a `test -f` guard inside the command), or produce something
   different from what the marker implies. The fingerprint protects the
   marker; only the command's own honesty protects the artifact.
2. **It is per-scenario.** Two scenarios that need the *same* artifact
   (the same lib version, the same binding build) each build it, because
   the key contains the whole assignment. z3 already works around this by
   building into shared contrib trees, which is why its build dirs then
   needed per-ref isolation.
3. **A new action starts cold everywhere.** Adding an action changes no
   existing step's fingerprint, but the new step has no marker in any
   scenario — fine. The real cost is the reverse: any change that renames
   the scenario dir (an enumeration change) orphans EVERY marker, and
   today's fix for that was to make the dir name content-derived rather
   than order-derived. That is a patch, not a model.

## 2. What an artifact cache would key on

The insight the three bugs share: **an artifact has an identity, and it
is not "the scenario that happened to build it"**. A built libsqlite3 at
3.46.1 is the same artifact whichever world asked for it. So:

```
artifact key = (artifact_info, provision, version, build inputs' identity)
```

- `artifact_info` — the enumeration's identity (a sum since 2026-08-24: kind plus whatever refines it);
- `provision` — Built / Installed / Fetched / Vendored: a staged lib is a
  DIFFERENT artifact from the build tree it came from (that distinction is
  now an enumeration axis, so the cache inherits it for free);
- `version` — the declared or measured version id;
- **inputs' identity** — the identity of what it was made from: the
  source ref for a Built lib, the built lib's key for a staged copy, the
  binding source's ref for a built binding. This is the piece today's
  fingerprint lacks, and it is exactly what made the staging copy-out
  uninvalidatable.

The store is then content-addressed-ish: `_out/canary/artifacts/<key>/`,
with scenario dirs holding SYMLINKS (or a manifest) into it. A scenario
becomes a set of artifact references plus its own step records.

## 3. What that buys

- **A new action runs without rebuilding.** Adding `Install_lib`, a probe
  location, or a check action creates new STEPS over artifacts that
  already exist under their keys — the expensive half is untouched. This
  is the user's stated requirement.
- **Sharing across scenarios.** The 2×2's four cells reference two libs
  and two bindings, not four of each. z3's 16 worlds reference three
  build trees. The build cost becomes O(distinct artifacts), not
  O(scenarios), which is what makes a wide matrix affordable.
- **Staleness becomes decidable.** "Is this artifact current?" is a key
  comparison, not a guess about whether a command did anything. The
  `.built-<version>` stamps added today are a hand-rolled instance of
  exactly this; the cache generalizes them.
- **Cross-project reuse.** Two projects wanting the same prebuilt (the
  `Vendored` conda-forge route) fetch it once.

## 4. Open questions, in the order they need answering

1. **Identity vs content.** Is the key DECLARED identity (version + input
   keys) or a content hash of the produced files? Declared is cheap and
   explains itself in the matrix; content is honest about a build that
   silently changed. Probably declared key + recorded content hash, so a
   mismatch is a FINDING (the same stance as staged parity: inspect the
   product, compare to the declaration).
2. **Where external build trees fit.** z3/llvm build inside contrib
   checkouts that canary does not own, and their per-ref build dirs are
   already a manual version of this. Does the cache adopt them by
   reference (a key pointing at an external path plus a recorded
   fingerprint), or stay out of their way?
3. **Eviction and size.** LLVM build trees are tens of GB. A cache with no
   eviction policy becomes a disk problem; a keyed store makes eviction
   possible for the first time (today nothing knows what is reusable).
4. **The relationship to step markers.** The step record should stay (it
   carries the VERDICT, which is not an artifact property). The proposal
   is to split the two concerns: markers record what happened, the
   artifact store records what exists.
5. **Interaction with `check_post`.** A postcondition proves an artifact's
   existence at a path; with a store, the natural check is "the key is
   present and its recorded hash matches", which is stronger and uniform.
   ⚠ That postcondition is itself being redesigned:
   [`action_model.md`](action_model.md) §9 step 6 derives it from the
   action × declaration join rather than from the hand-written
   compositors, and §10 there records why the two documents stay
   separate. The two designs must agree on ONE question — what a
   postcondition asserts about an artifact — so whichever lands second
   reads the other first. §6 below is the argument this document
   contributes to it.
6. **The key must carry the WORLD'S TOOLCHAIN, and nothing records it**
   (2026-09-16). Two libraries built from the same source ref by
   different compilers are different artifacts — different symbol
   mangling, different `NEEDED`, different ABI — and a key that cannot
   say so will serve one for the other. Today neither `step_fingerprint`
   nor `run_info` records a compiler or a linker. The opam SWITCH and
   the PLATFORM are already on the fingerprint (2026-08-26), which is
   the same class of fact and shows the shape: detected once, carried on
   the run config, printed in the header, part of the fingerprint. The
   toolchain is the next member and it is a prerequisite for the store,
   not a refinement of it.
7. **`step_identity.md` is this problem from the other end.** A step's
   TAG depends on how many siblings it has, so adding a second probe
   renames the first — and the tag is part of the marker path. That is a
   cache-key defect wearing a naming hat, and the store inherits it
   unless identity stops depending on the size of the set it is in.

## 5. Suggested first step (small, and it pays immediately)

Do not build the store first. Instead make artifact identity EXPLICIT
where it is already implied:

1. every make/copy/install command names the identity of what it produces
   (today: sqlite's `.built-<v>` / `.staged-<v>` stamps — generalize the
   convention, then test it);
2. a step's fingerprint includes the identity of its INPUT artifacts, not
   only its own command text — that single change would have caught the
   stale-staging bug automatically;
3. then the store, once identity is trustworthy.

Reversing that order would build a cache keyed on identities nothing
currently guarantees.

**Step 0, done 2026-09-16:** the global CI cache is gone (§1). It was
not a step toward this; it was a second cache answering a different and
wrong question, keyed on a name, bypassing every gate this one earned.

## 6. The second specimen — two caches agreed about a wrong artifact

*(Absorbed from `enumeration/run_model_revisit.md` §3, 2026-08-24. §5's
step 2 was a proposal supported by one instance; this is the second, in a
different project and a different build system, and it sharpens the
proposal.)*

`build-pre-10549/src/api/ml/dllz3ml.so` was linked against
`libz3.so.5.0` while the tree's own lib exports `SONAME libz3.so.5.1`,
and no `libz3.so.5.0` exists on this machine. Both caching layers behaved
**correctly by their own rules** and the result was still a lie:

| layer | what it checks | verdict | correct? |
| --- | --- | --- | --- |
| ninja | did any recorded input of this target change? | up to date | yes, by its rules |
| canary's step marker | same realized command + expectation, and `check_post` passes? | warm skip | yes, by its rules |
| reality | does the binding load the lib beside it? | **no** | — |

Neither layer models the thing that changed: **the identity of the input
artifact**. libz3 bumped soname 5.0 → 5.1, and nothing in either key
mentions the soname, the version, or the content of the library the
binding links against.

**What it adds to §5.** The earlier framing was about canary's own cache.
Here the *external* build system had the same blind spot, which means
canary **cannot delegate the question to it**: "ninja said it was up to
date" is not evidence about the artifact. A canary step that shells out to
a build tool has to check the product itself.

**The cheap instance, available before the store exists:** a
post-`build_binding` assertion that every `NEEDED` entry naming the
project's lib matches the soname the tree's lib exports. That catches this
class at the step that produced it. Tracked in
`../project/status_project.md`.

# Canary projects — how to land one

The landing guide: the workflow, the data structures to write, and the
testing harness that verifies each step. Split out of `index.md` in the
2026-08-12 reorganization (a future `onboard-new-project`-style skill
will be built on this doc — the previous skill was retired the same
day). Coverage status is [`coverage.md`](coverage.md); bugs/todo in
[`status_project.md`](status_project.md); the conceptual model in
[`index.md`](index.md) §1.

---

## 1. Mechanics — adding a new project today

Each project lives in `src/canary/project/canary_project_<name>.ml` and is
wired by **one registry entry** in
`src/canary/project/canary_registry.ml`. Three entry shapes, cheapest
first:

- **`simple` (Pattern A)** — system lib + opam binding, no source build.
  The `canary_pattern_a.ml` template brings each spec down to ~40 lines
  (`runner_spec`), then
  `let <name>_run = Canary_project_run.simple ~name ~runner_spec` wraps
  it as a `project_run` (lib + binding Fetched@Stable → exactly 1
  scenario). Registry entry: `("<name>", <name>_run)`. zarith,
  cairo, libffi.
- **`project_run` (generic path, Level C)** — the project declares DATA:
  a `pr_spec` universe table (artifact × (provision × versions)) +
  artifact rows with providers, and `pr_runner_spec = realize ∘
  dispatch` over an action table. The general enumeration computes the
  scenario list; `run_project_run` executes it. tiny-full, sqlite, z3,
  llvm, ssl. See [`../design/ssot.md`](../design/ssot.md) §6.1 and
  [`../design/algorithm_explainer.md`](../design/algorithm_explainer.md).
- **store pins** — a binding whose provider declares `versions`
  (`Lang_pkg`) enumerates one scenario per pin; the fetch is a
  pin-checked store operation (warm-skip only when the switch provably
  holds the pin) and the probes carry world assertions. ssl is the
  reference shape (2 scenarios × 2 probes). See
  [`store_switching.md`](store_switching.md).

Source-built projects are still the expensive ones — z3 ~600 lines, llvm
~470 — and A5 made their *shape* identical without yet sharing their
command templates.

**The landing workflow** (the full loop):

1. **Pick a coverage level** (§5: A positive-only / B derived failure /
   C scenario matrix) and write the per-project plan checklist first:
   - which native library + which binding(s) — explicit artifact kinds;
   - install paths per PM (apt / brew / opam / pip / conda);
   - watchlists — native symbols, OCaml modules, Python attrs (this is
     also the *evidence* a Level-B prediction is derived from);
   - probe examples — a small program that exercises the binding;
   - expected drift / failure cases — which contract (c1..c8) ought to
     attribute it;
   - open questions that only surface during implementation.
2. **Write `canary_project_<name>.ml`** + `canary/examples/<name>/`
   probe. Reuse tool/ primitives (`canary_build_cmd`,
   `canary_artifact_native`, `canary_artifact_lang`,
   `canary_action_table`) — framework infra is consumed, never forked.
3. **Add the registry entry** — that alone wires `action`, `spec`,
   `scenarios`, and the `@all` sweeps; the bin layer has no per-project
   cases anymore.
4. **The testing harness** (each step guards the previous):
   - `dune build` after every edit;
   - `make canary-test` (pure project-test + artifact-test + pm-test);
     the `registry.entries_enumerate` pin fails if an entry's
     enumeration is empty or the name list drifts;
   - `canary action <name>` — first full run, read
     `_out/canary/projects/<name>/-run/actions.log` on failure;
   - `canary spec <name>` / `canary scenarios <name>` / `canary status
     <name>` — the three display surfaces;
   - `make canary-post-check` before commit.
5. **After landing**: move from the queue table to
   [`coverage.md`](coverage.md)'s landing history, add the status-matrix
   row, update `CLAUDE.md`'s project list, and file any rough edge in
   [`status_project.md`](status_project.md).

---


## 2. Scenario coverage — three levels, pick one

New projects choose *how much* scenario coverage they want.
tiny1 is not the reference to copy; it's the framework's
own regression suite. Pick the level that matches the
project's purpose:

| Level                               | What you write                                                                                                                                                       | Example                                                                                                                           | When it's right                                                                                                                                     |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A. Positive-only**                | `runner_spec` + `api_source` + probe examples that must build/run. No failure prediction.                                                                            | zarith, cairo (system lib works; probe compiles)                                                                                  | The project is a demo that a canary session terminates cleanly on a known-good setup. No version-mismatch or breakage story.                        |
| **B. A derived failure prediction** | Level A + enough declared **evidence** (watchlists / `api_source`) for the shared lowering to find the break itself. Since A7 you do *not* hand-write the substring. | z3 (`parser_context` missing from the wheel → `xfail[c2]`), llvm (`Opcode.UncondBr` → `xfail[c2]`), ssl (`060_nlv` → `xfail[c2]`) | You want to demonstrate a real version drift on this project. Cheapest way to say "here's an API break canary *computed*".                          |
| **C. Scenario matrix**              | Level B + a `pr_spec` universe declaring the provision/version axes; the general enumeration produces the scenarios.                                                 | tiny-full (6), sqlite (3), z3 / llvm (2 each)                                                                                     | You want *systematic* coverage across an artifact's provision/version axes. No longer exotic — it is the default shape for a `project_run` project. |

**Do not copy tiny's workspace/prepare/baseline files.**
`canary_tiny_workspace.ml` + `_prepare.ml` + `_baseline.ml`
are framework infrastructure for driving tiny1's 22-scenario
mutation **oracle** through sandboxed builds — a *test harness* for the
framework itself, not a template. No level needs them: a Level C project
declares axes in its `pr_spec` and the general enumeration does the rest
(tiny-full, the project, is itself a `project_run` peer of sqlite — it
does not fork the factory).

**Effort ballpark** (per level, per project):

- **A**: ~40 LOC via `canary_pattern_a.ml` (Pattern A: system lib + opam binding), ~600 LOC hand-written for a source-built project (z3/llvm shape).
- **B**: A + the watchlist/`api_source` entries that carry the evidence — usually ~10-20 LOC, no expectation code.
- **C**: B + the `pr_spec` universe table + `realize ∘ dispatch` (sqlite: ~300 LOC including the from-source build; z3/llvm: the bulk is their build commands, not the scenario machinery).

For scenario mechanics + the derived-vs-hand principle see
[`design/algorithm_explainer.md`](../design/algorithm_explainer.md).

## 3. Sourcing the lib channel pair (rule, user 2026-08-19)

Every project needs a stable/latest pair per artifact (the 2×2 lower
bound). For the C lib the pair is sourced in a FIXED order — the point is
to test against what users have and what is coming, never against
archaeology:

1. **stable = the system PM.** Whatever apt/brew ships is the version
   real users link against. That is the pair's stable side, always.
2. **latest = the official download, if the project publishes a prebuilt
   binary for our platform.** Check the project's own site / GitHub
   releases first — it is the authoritative artifact.
3. **latest = conda-forge's newest versioned release**, when upstream
   publishes source only (the common case on Linux). Prebuilt, versioned,
   and extractable; declared `Vendored` at
   `contrib/<project>-all/prebuilt/<tag>/` (see
   [`../design/multi_lib.md` §6](../design/multi_lib.md)).

**Do not reach for an OLD version to manufacture a gap.** An earlier draft
of this table proposed cairo 1.18.0 vs 1.14.12; that is backwards. The
question a pair asks is "does today's binding still work with tomorrow's
lib, and does yesterday's binding still work with today's" — both are
answered by pairing the system version with the NEWEST. An older lib
answers a question nobody has (the binding predates it).

### What the rule yields for the current projects (measured 2026-08-19)

| lib | official newest | official Linux prebuilt? | apt = stable | conda-forge newest | pair |
| --- | --- | --- | --- | --- | --- |
| **gmp** | 6.3.0 (2023-07-30) | no — source only (lz/xz/zstd) | 6.3.0 | 6.3.0 | **none possible**: apt already ships upstream's newest |
| **openssl** | 4.0.1 (2026-06-09) | no — source only | 3.0.13 | 4.0.1 | **3.0.13 vs 4.0.1** — a major bump |
| **libffi** | 3.8.0 | no Linux (MSVC/Windows assets only) | 3.4.6 | 3.7.0 | **3.4.6 vs 3.7.0** |
| **cairo** | 1.18.4 (2025-03-08) | no — source `.tar.xz` | 1.18.0 | 1.18.4 | **1.18.0 vs 1.18.4** |

Three consequences worth carrying into every landing:

- **zarith cannot have a lib pair at all.** Not an oversight and not an
  opam problem (`conf-gmp` constrains nothing): GMP's newest release is
  three years old and apt already ships it. When upstream and the distro
  agree, the axis has one point — the honest spec says so.
- **No Linux C library in this set ships an official prebuilt.** On Linux
  the distro *is* the binary channel, so step 2 will usually fall through
  to step 3. Keep step 2 anyway: it is authoritative where it applies
  (llvm's apt.llvm.org, and any project shipping release binaries).
- **conda-forge can lag upstream.** Measured: current for openssl (4.0.1),
  current for cairo (1.18.4), one release behind for libffi (3.7.0 vs
  3.8.0). Good enough to be the fallback, not good enough to be assumed —
  record the version you actually vendored.

## 3b. Measuring the gate — `opam show` is necessary, not sufficient
### (rule, 2026-08-20, from the conf-* survey sampling)

The landing checklist says to MEASURE `pm_gate` rather than guess it. Two
measurements found on 2026-08-20 say that reading
`opam show <binding> --field=depends` alone gets it wrong in both
directions. Do all three steps:

1. **Read the binding's declared constraint** — as before.
2. **If there is a version bound, open the CONF PACKAGE and check
   whether its own check enforces a version.** Two mechanisms exist and
   they look nothing alike: a pkg-config predicate with a hardcoded
   literal (`pkg-config --atleast-version=1.3.8 libzstd`), or the opam
   `version` variable fed to a discovery script
   (`["bash" "configure.sh" version]`). Measured: **13 of 370** conf
   packages carry one — run
   `python3 doc/canary/raw/conf_version_carriers.py` for the current
   list rather than trusting a remembered one. Everywhere else the bound
   is over opam PACKAGING and the lib is unconstrained:
   `conf-libffi.2.0.0`'s entire build is `pkg-config libffi` while libffi
   is 3.x. Record the answer as `Bounded_with_conf { tracks_lib }`;
   `false` derives `Any_version`.
3. **Read the binding's own `build:` for a version test.** `mlmpfr`
   compiles and runs a C program that reads `MPFR_VERSION_*` and aborts
   the build on an older lib — a hard gate with a *bare* `"conf-mpfr"`
   dependency. `opam show` cannot see it. Grep the package's
   extra-source files for `VERSION_MAJOR` / `-ge` / `sort -V` before
   declaring a gate free.

Failing step 2 overstates the difficulty (we would go build a wrapper for
libffi that nothing requires). Failing step 3 understates it (we would
declare mlmpfr free and be surprised by a build abort). Both are recorded
with evidence in [`../surveys/conf_packages.md` §G1](../surveys/conf_packages.md).

**Do step 2 with the script, not from memory.** The first sweep behind
this rule found only one of the two mechanisms, because it stripped
quoted strings before searching — correct for finding the `version`
variable, and exactly wrong for finding a hardcoded literal, which lives
inside the quotes. It reported a clean "5 of 370" and the landing that
immediately followed (`zstd`) pulled `conf-zstd.1.3.8`, whose build is
`--atleast-version=1.3.8`. Same shape as §4's lessons: the check ran, and
had nothing in front of it.

## 4. Landing lessons — the bug classes that bit us (keep re-reading)

Recorded because they recur, and a new project with a similar shape will
hit them (user, 2026-08-19: "any fix is worth recording since we need to
learn from them on how to land more projects which may have similar
issues"). Each is a check that did not check.

**A fingerprint protects the MARKER, not the ARTIFACT.** The warm-skip
gate hashes a step's realized command + expectation form, so a spec edit
re-runs the step. It cannot know whether the step then did anything. Two
ways that bites, both live:

- *a guard inside the command*: sqlite's `build_lib` was
  `test -f <lib> || build`. Changing the declared amalgamation version
  re-ran the step, and the command said "the lib is already there" and
  skipped the compile — the world kept the OLD lib and reported PASS.
  Fix: make the guard carry the identity (`.built-<version>` stamp).
- *a command that doesn't name its input*: sqlite's staging copy-out
  (`cp <ws>/lib/... <ws>/install/lib/`) has identical text whatever it
  copies, so its fingerprint could not change when the lib did — the
  staged prefix kept a stale lib. Fix: name the version in the command.

Rule for a new project: **every build/copy/install command must encode
the identity of what it produces**, or its cache entry is a lie.

**A check appended after an `exit` never runs.** `with_world_asserts`
appended `&& grep …` to probe commands that end in `exit $RC` (every
env-wrapped probe), so sqlite's declared runtime version assertion had
never once executed. It was invisible precisely because it "passed".
Fix: the wrapped command runs in a subshell. Rule: when you add a check
by string concatenation, verify it RAN — make it fail once on purpose.

**A shared staging area lets one world answer another's question.** z3's
install prefix was the build tree's sibling, shared by two refs, so the
fork's staged package would have satisfied the pre-10549 world's staged
probe and silenced its xfail. Rule: any write location a realization
names must be per-world (`build-<ref>`, `install-<ref>`,
`prebuilt/<tag>`).

**A declared check whose inputs never resolve is silent.** The forward
cell's c1 wrote its summary into a lang-less directory while its own
input template read the lang-suffixed one; the pair never resolved and
"no contract fired" read like "nothing to report". Rule: a new contract
wiring is not done until it has FIRED once.

**Assert the world, don't observe it.** The backward cell's probe prints
the lib version it loaded, which is evidence a human can read — but
nothing fails if the wrong lib answers. Where canary controls the version,
assert it (and where it does not — a system lib — assert nothing rather
than assert a version you only hope for).

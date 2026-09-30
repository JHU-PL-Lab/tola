# Three directions, explored and recorded

**Kind: exploration.** Not design and not a plan — what was found by
looking, per direction, with the decisions that have to be taken before
any of it can be built. Each section ends with where it lands when it
lands.

> 2026-09-17, from the user before a break: *"There are several things
> in my mind for next… when in doubt, explore more and record them."*
> Five directions were asked about. Two had homes already and went
> there: the provider-linkage axis is
> [`agreement/components.md`](agreement/components.md) §3.4, and the
> recovery grid shipped (`canary checks --firing`, second table). The
> three here have no home yet, which is why they are together.

| | direction | the short answer |
| --- | --- | --- |
| §1 | cross-package-manager, and the `conf-*` hop | the conversion is lossy in a NAMED way, and the loss is checkable |
| §2 | correspondence tests (`push`/`pop` on both sides) | the oracle is the other side of the binding, which canary already builds |
| §3 | versioning, ELF vs Mach-O | the evidence is already recorded and nothing reads it |

---

## 1. Cross-package-manager: what can be checked across the `conf-*` hop

**The question, from the user:** *"cross-package managers especially
opam-with-conf-`<pkg>`… our checking spirit is to make combination
beyond a package's current opam-style. So given an arbitrary OCaml
binding package with a C lib dependency, how can we combine and
enumerate them."*

### What the survey already established

[`../surveys/conf_packages.md`](../surveys/conf_packages.md) §H1 states
the mechanism precisely, and it is the sentence everything else follows
from:

> A `conf-<lib>` package converts *"this opam package needs library L"*
> into *"this OS needs system package P"*, via `depexts:` keyed on
> `os-family` / `os-distribution`. The conversion is **one-way and
> lossy**. It carries two things — that something satisfying the check
> is present, and a distro package NAME — and drops two others: the
> VERSION actually found, and any ability to CHOOSE among several.

Scale, from [`../surveys/opam.md`](../surveys/opam.md): 4460 package
families, 333 `conf-*` of which 205 are for C libraries, 929 packages
C-involved. 208 of the 333 do nothing but `pkg-config --exists`, and
**only 13 of 370 carry a real version bound** (§G1a).

### The finding: the loss is NAMED, so it is checkable

Each dropped thing is an agreement candidate, and each is d0 or d1 — the
evidence is at hand.

| what the hop drops | the claim it makes checkable | evidence | status |
| --- | --- | --- | --- |
| the version found | *the library the conf check ACCEPTED is the library the binding LINKED* | the conf check's resolution (pkg-config `--modversion`, or the compiled test's include path) vs the consumer's recorded `NEEDED` / the loader's answer | **nothing records the first half** |
| the choice | *the depext package installed is the one that provided the library* | the system PM's file list for package P vs the resolved library path | `dpkg -S` / `brew list` exists; unmodelled |
| — | *the presence test and the LINK resolve to the same object* | three resolvers can disagree: `pkg-config --libs`, the linker's `-L` search, the loader's `RUNPATH` | the ncurses report is one instance of exactly this |

The third is the one worth naming first. **`conf-*` runs a
`pkg-config`-shaped presence test at SOLVE time; the binding links at
BUILD time; the app loads at RUN time. Three resolvers, three moments,
and nothing checks that they agreed.** That is the same shape as
`dependencies_provided` but one hop earlier, and it is the mechanism
behind the finding already written up in
[`../project/report_ncurses_libtinfo.md`](../project/report_ncurses_libtinfo.md):
identical sonames, identical symbols, identical version nodes, and a
segfault, because two prefixes answered differently.

Provisional name for it, if it survives review: **`discovery_matches_link`**
— *the object the discovery mechanism accepted is the object the link
resolved.* It roots in no toolchain's rule (nothing enforces it), which
puts it with the three unrooted ones — **except** that unlike them it has
an oracle: run both resolvers and compare paths. Worth deciding whether
"rooted" should mean *a tool enforced it* or *a tool ANSWERED it*, since
`pkg-config` does answer.

### The enumeration question, which is the easier half

*"Given an arbitrary OCaml binding package with a C lib dependency, how
can we combine and enumerate them."*

Canary already does this, and the opam-binding template is the answer:
the binding is one artifact row (opam, a pin pair) and the library is
another (apt / brew / conda-forge / built), and the enumeration takes
their product. What opam gives you is ONE cell of that product — whatever
the distro happened to have — and enumerating the rest is the whole
point.

So the work is not new machinery. It is:

1. **Lift the depext dispatch to a table.** The survey's refinement
   already says so: *"keep that dispatch as a GLOBAL mapping file"*.
   Canary's `system_package_spec`'s `linux_pkg` / `macos_pkg` pair IS
   that data, declared per project — the same table keyed by library
   name, which is what makes an ARBITRARY package landable instead of a
   hand-written spec each time.
2. **Read the conf package rather than restating it.** For the 208
   pkg-config cases the lib axis is derivable: the conf package names
   the pkg-config module, `pkg-config --modversion` gives the version
   point, `depexts:` gives the system package per distro. A spec could
   be GENERATED for those, which is the difference between landing one
   project a week and landing a hundred.
3. **Then the checks above**, which need (1) to know what to compare
   against.

### ⚠ Two traps the survey already paid for

- **`flags: conf` does not mean "installs nothing".** Five of 377 have an
  `install:` field, and `conf-libssl`'s is platform-conditional —
  virtual on Debian, installing files on Homebrew. Anything assuming
  "conf ⇒ nothing on disk" is right 372 times and wrong in a
  platform-dependent way, which is the worst shape (§H2).
- **`lib<pkg>` packages are `Vendored` wearing a `Lang_pkg` label** and
  they FREEZE: libtorch 2.2.1 vs upstream 2.13.0, libtensorflow pinned
  at 1.10.0 since 2018. Before taking one as an axis point, check how
  far behind it is (§H3).

### Where this lands

A new agreement needs a `components.md` section to root it (§5 is
packaging) and a registry row. The enumeration half is
`tool/canary_store_config.ml` plus a table. **Land the table first** —
it is useful with no agreement at all, and the agreements need it.

---

## 2. Correspondence: testing that both sides of a binding do the same thing

**The question, from the user:** *"the correspondence of the same
operations that perform on both sides of the binding — saying we have
`pop`/`push` in both the C side and the OCaml side, how shall we
construct the tests and how to integrate them into the project."*

### Where this sits today

`behavior_matches` is the registry row for it, and it is one of the
three with **no evaluator and no root**. Its stated blocker is that *"the
expected values live inside the probe's source"* — the project has to
state what the right answer is, and nothing can read that.

### The finding: the oracle is the other side, and canary already builds it

That blocker dissolves for the correspondence case specifically, and the
reason is worth stating carefully.

For a **differential** test — run the operation through the C API and
through the binding on the same inputs, compare the results — **no
project-supplied expectation is needed at all.** The C side IS the
expectation. And canary is unusual in being able to do this: it already
builds the library and the binding in one world, so both callers are on
hand.

**What this recovers, in theory's terms.** `build_binding`'s tool — the
C compiler — established that the stub's types agree with the header.
Everything ABOVE the types it did not establish: the conversion at the
boundary (an `int` that is an `int32` on one side and an `int63` on the
other), the error and exception mapping, ownership and lifetime, and
anything stateful — which is what `push`/`pop` is. Those are real
projection losses at a real edge, and a differential test is the only
thing that recovers them.

> ⚠ **ARGUMENT ORDER IS NOT ONE OF THEM**, and an earlier draft of this
> section had it wrong (corrected 2026-09-17, user: *"the order should
> be kept by convention if possible — if we know `tiny_sum(a,b)` maps to
> `sum a b`, then testing `sum b a` is not related here"*).
>
> The correspondence is DEFINED BY the declared mapping. A binding that
> binds `tiny_sum(a,b)` to `sum b a` is not a wrong binding, it is a
> different one, and a test that flagged it would be testing a
> convention nobody stated. The right reading is the opposite and it is
> stronger: **because the positional convention holds, the test is
> GENERATABLE.** Pair the C function with the binding function by name,
> feed the same arguments in the same order, compare. Nobody writes the
> pairing.

**But it is not the same claim as `behavior_matches`,** and merging them
would repeat the solo/pair mistake:

| | the claim | the oracle | rooted? |
| --- | --- | --- | --- |
| correspondence | the binding computes the same function as the C API | the C side, run here | in nothing — but it has an oracle without a spec |
| `behavior_matches` | the library does what the project says it does | a project-supplied expectation | in nothing, and it has no oracle |

So: **a distinct agreement**, provisionally `binding_computes_the_same`,
rather than an evaluator for `behavior_matches`.

### It is a GENERATOR, not a test

The user's framing, and it changes the deliverable: *"the `push`/`pop`
[is] a logic to generate test cases, and the source can come from the
existing tests, or generated from our framework."*

So there are two inputs and one engine.

| source | what it gives | cost |
| --- | --- | --- |
| **the project's existing tests** | real cases, upstream's own idea of what matters, no invention | a translation per project; a failure implicates the translation |
| **generated from the declaration** | uniform, free per project, and it scales to any binding that declares its `c_api` | only reaches what the types admit — it cannot invent a meaningful input for an opaque handle |

**Generated is the one to build first**, because `binding_decl` already
carries what it needs: `c_api.functions` is the pairing, the positional
convention is the argument mapping, and the arity plus the types give
the input space. A generator over that is per-FRAMEWORK, written once;
a translation is per-PROJECT, written every time.

Stateful sequences (`push`/`pop`) are where generation earns its keep:
the interesting cases are SEQUENCES, and enumerating short sequences
over a small operation set is exactly what a generator does well and a
human does badly.

### Where the generator lives

**`action/canary_correspondence_gen.ml`**, a sibling of
`canary_binding_templates.ml`. That module already does
`binding_decl × ctx → command builders`; this one does
`binding_decl → driver source`. Same input, same layer, same reason to
be in `action/`: it is a pure function from a declaration, and the
project supplies no part of it.

It emits two drivers plus a case file per binding: the C driver, the
binding driver, and the inputs they both read. Canary never runs them —
the fork's build does — so the generator produces TEXT and nothing else,
which also makes it unit-testable with no world.

### Where the generated files live, and how git should carry them

**The fork**, and the reason is that a driver must COMPILE against the
project's own headers and build system: in the fork it is an ordinary
target, under `canary/` it needs the include paths reconstructed, which
is the locator problem again ([`action_model.md`](action_model.md) §5)
and we have three vocabularies for it already.

**But not on the fix branch**, which is the user's concern: *"does the
committed testcase bring more concerns if we want to make a PR that
targets an api bugfix?"* Yes it does — and canary has already answered
this question once, for packaging, in
[`wrapper_packages.md`](wrapper_packages.md) §1. The rule there
generalises exactly:

> Putting it in the fork would (a) duplicate it per ref, (b) **pollute
> the upstream-reportable fix branch with workflow concerns upstream
> would never merge.**

So: **a branch is PR-ready or it is workflow, never both.**

| branch | holds | ever PR'd? |
| --- | --- | --- |
| `fix/<thing>` | the bugfix alone, off upstream | **yes** — this is the PR |
| `canary/correspondence` | the generated drivers and cases | **no** |

The two never merge. `canary/correspondence` rebases onto the fix branch
(or onto upstream) so it always tests the current tree; nothing flows
the other way.

**When a generated case finds a bug, the PR does not carry the
generator's output.** It carries a hand-minimised reproducer — which is
a different artifact with a different purpose: generated cases are for
FINDING, a minimal case is for REPORTING, and a maintainer reviewing a
one-line fix should not be handed a corpus. That split is also why the
noise question has a clean answer rather than a trade-off.

### Canary still tracks it, because canary regenerates it

The user's point, and it decides the shape: *"even it should be in the
fork, we (canary) shall still track it, since canary may update it."*

Two consequences:

1. **The branch is a repo record**, exactly like z3's `arbipher` fork —
   a `Repo_axes` entry with `label = Some "canary-correspondence"`,
   `official = false`, and a ref. That is machinery canary already has,
   and it means the branch is a version point the enumeration can range
   over rather than something a human remembers to update.
2. **The drivers are a BUILD PRODUCT under version control**:
   committed so the fork builds without
   canary present, generated so they cannot drift from the declaration.
   The pin is the same shape — regenerate, diff, fail if they differ —
   and it is the reason to keep the generator pure text.

The pin has to run where the fork is checked out. Decide that integration
before writing the generator:
either canary regenerates into the fork and diffs (needs the checkout,
which the source-repo record already gives it), or the fork's own CI
runs the generator (needs canary installed there). **The first**, for
the same reason the round-trip gate lives here: canary owns the
assertion that its own output is current.

### How to construct the cases

Three shapes, cheapest first. tiny is the specimen: it already has the
two-layer structure (`Tiny_raw`, the 1:1 foreign-call layer, and `Tiny`,
the user-facing repack whose docstring says *"today the repack is the
identity modulo a rename"*).

1. **Paired drivers, shared inputs.** A C program and an OCaml program
   that each read the same input vector and print the same output
   format; compare the two transcripts.
   ⚠ It compares TRANSCRIPTS, so the print must be canonical — the same
   trap as `nm` output formats: *an assertion that compares tool OUTPUT
   must state the format it wants.* Generate BOTH printers from one
   spec rather than writing them twice.
2. **Sequences, for stateful APIs.** `push`/`pop` has no meaningful
   single-call test; the case is a sequence and the comparison is the
   trace. Enumerate short sequences over the operation set, bounded by
   length, with the same seed on both sides.
3. **The project's own suite, run through the binding.** Strongest and
   most expensive; a failure implicates the translation as much as the
   binding. Keep for last, and use it to CHECK the generator rather than
   to replace it.

**Start with 1 on tiny.** The fault to inject is not an argument swap —
it is a CONVERSION fault: make `tiny_sum` return `int32` where the stub
reads `int`, or have the repack layer drop `tiny_offset`'s contribution.
Both are invisible to every structural agreement in the catalogue, and
both are what a differential test is for.

### How to integrate it

This is where it meets the action model, and the answer is not obvious.

- A differential test is **role 3** of
  [`action_model.md`](action_model.md) §4 — *execution* — on both sides
  at once. `probe_binding` already fuses existence, inspection and
  execution; adding a fourth thing to that `&&` chain is how the fusion
  got bad in the first place.
- It needs an artifact the graph does not have: a **C driver**. That is
  `build_app` with `lang = C`, which the vocabulary can express
  (`app_wiring`) and no project declares.
- So the honest shape is a **new action**, `probe_correspondence`,
  consuming the lib and the binding and producing a comparison — and
  [`action_playbook.md`](action_playbook.md) §1's ten touch points is
  the procedure.

**Decide before building:** whether the C driver is an `App` artifact
(uniform, and gets the whole chain for free) or a fixture the probe
compiles inline (cheap, and invisible to the enumeration). The first is
right and the second is what will be tempting.

### Where this lands

`components.md` §6.3.2 is the section (behavioural observations); the
agreement is a new row with `ag_rooted_in` stating honestly that no tool
enforced it; the action is new; the generated drivers live in the fork.

**The mutation comes first** — a conversion fault in tiny that nothing
currently catches is the evidence that the agreement is worth having,
and it costs one line of C. Then the generator, then one `push`/`pop`
specimen with real state, then the action.

---

## 2b. An open question the firing fix left behind

When the declaration claims began firing in Fetched worlds (2026-09-17),
one case was deliberately left as it was: **Installed**.

Today they fire at `build_lib` in an Installed world, reading the BUILD
TREE's copy — while `lib_evidence_tags` puts the STAGED summary first for
exactly that world. So the firing and the evidence disagree about which
of the two libraries the claim is about.

Both readings are defensible:

- **fire at `build_lib` only** (today) — the declaration is about what
  the build produced, and whether staging preserved it is
  `staged_interface_preserved`'s question. Composition, not duplication.
- **fire at `install_lib` as well** — the staged library is the one a
  consumer actually loads, so "does the artifact people use export what
  we declared" is a distinct and checkable claim. It would decide on
  sqlite and z3, the two projects with Installed worlds.

The second is probably right and the first is probably cheaper, and the
deciding question is whether
`staged_interface_preserved ∘ declared_symbols_exported` really implies
the staged claim — it does only if staging preserves the export set
exactly, which is what `sip` checks, so the composition is sound. That
makes this a question about REPORTING (does a reader want the claim
stated at the artifact they use?) rather than about coverage.

⚠ Whichever way it goes, the firing and `lib_evidence_tags` must agree.
They currently do not, and that is the bug class this repository keeps
paying for.

## 3. Versioning: ELF and Mach-O do not agree, and we model one of them

**The question, from the user:** *"we also don't discuss the versioning
yet, given elf/mach-o has its conversion. (we know the semantic
versioning in use is never semantics). How shall we plan to land more
checking and how to apply them in these projects."*

### The finding: the evidence is already recorded and nothing reads it

`canary/scripts/inspect_native.py` has parsed Mach-O's `LC_ID_DYLIB`
since the macOS port, and its docstring says what it is for:

> Two EXTRA fields with no ELF counterpart: `compatibility_version` and
> `current_version` from `LC_ID_DYLIB`. They are the Mach-O version
> gate — dyld refuses a library whose `compatibility_version` is below
> what the consumer recorded.

Nothing in `src/canary/agreement/` mentions either field. **This is
written evidence with no reader** — the inverse of the usual gap, and
the cheapest agreement available anywhere in the tree.

It is also already analysed: `../project/issues.md` and
[`platform.md`](platform.md) §5 both record the open decision.

### The three-layer version picture, which the docs do not draw

Canary's agreements live at one layer. The other two are unmodelled, and
the user's parenthesis — *semantic versioning in use is never semantic*
— is exactly about the gap between them.

| layer | ELF | Mach-O | who enforces it | canary |
| --- | --- | --- | --- | --- |
| **package** | `libfoo1 (= 1.2.3-4)` | `foo 1.2.3` | the solver, at install | enumerated as a version point; `pin_check_post` verifies the store |
| **library identity** | `SONAME libfoo.so.1` | `install_name .../libfoo.1.dylib` + **`compatibility_version`** | the loader, at load | `soname_matches_*` — ELF-shaped |
| **symbol** | version nodes (`GLIBC_2.2.5`) | **nothing** | the loader, per symbol | `*_versions_exported` — ELF-only by construction |

Three asymmetries fall out, and each is a decision:

1. **Mach-O has a version FLOOR that ELF does not.**
   `compatibility_version` is a number dyld compares and refuses on. ELF
   has no library-granularity equivalent — its floor is per-symbol. So
   the claim *"the provider satisfies the consumer's recorded version
   floor"* exists on both platforms **at different resolutions**, which
   is the more interesting reading for the manuscript: a surface theory
   has to be parametric in the resolution, not in the presence, of a
   version gate.
2. **`install_name` is a PATH, not a name.** `soname_matches_declaration`
   compares names. On Mach-O the recorded value is
   `@rpath/libfoo.1.dylib` or an absolute path, so the comparison needs
   a basename normalisation that the ELF path never needed — and doing
   it silently would hide a real class of bug (a dylib whose
   `install_name` points somewhere it is not).
3. **The package version is not the library version, ever.**
   [`agreement/components.md`](agreement/components.md) §4.2 says so; the conf survey measures it (13 of 370 conf packages carry a real
   version bound). The agreement that would state it —
   *the installed package's version names the library's recorded
   identity* — is checkable wherever a system PM answers
   (`dpkg-query -W`, `brew info --json`), and is unclaimed.

### What to land, in order

1. **`compatibility_version_satisfied`**, a new agreement, Mach-O-only
   applicability. Evidence: both halves already extracted. Falsifier:
   bump the provider's `compatibility_version` below the consumer's
   recorded value and watch dyld refuse. Rooted in **dyld's rule**,
   which puts it with the ten tool-rooted ones rather than the three
   waiting on a spec.
   ⚠ It needs a macOS run to land, and `canary checks --landing` is
   platform-blind — an agreement landed only on mac would read as
   landed everywhere. **That is a reporting gap to settle first**, and
   it is the same question `platform.md` §6 asks about the cross-platform
   viewer.
2. **`install_name` normalisation**, in the identity family, with the
   un-normalised value kept in the finding so a wrong path is still
   visible.
3. **`package_version_names_the_library`**, the third layer. Needs a PM
   query per manager — `Canary_pm_*` already has the shape
   (`installed_version_cmd`).

**Do 1 first.** It is a landed inspector, a real loader rule, a cheap
falsifier, and it is the only one of the three that tells us something
about the THEORY rather than about a package manager.

### Where this lands

`components.md` §4.1 is the section and it is currently three sentences
long — *"The detailed version-pair observations remain to be
developed"*. It should carry the three-layer table above. The
platform-blindness of the landing report is
[`platform.md`](platform.md) §6's question, and it blocks (1) from being
reportable even once it works.

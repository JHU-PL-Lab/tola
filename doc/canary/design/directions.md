# Three directions, explored and recorded

**Kind: exploration.** Not design and not a plan — what was found by
looking, per direction, with the decisions that have to be taken before
any of it can be built. Each section ends with where it lands when it
lands.

> 2026-09-17, from the user before a break: *"There are several things
> in my mind for next… when in doubt, explore more and record them."*
> Five directions were asked about. Two had homes already and went
> there: the provider-linkage axis is
> [`mechanism.md`](mechanism.md) *"The axis that is missing"*, and the
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
| — | *the presence test and the LINK resolve to the same object* | three resolvers can disagree: `pkg-config --libs`, the linker's `-L` search, the loader's `RUNPATH` | the ncurses report (§5.5) is one instance of exactly this |

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

**What this recovers, in theory's terms.** `build_binding`'s tool — the C
compiler — established that the stub's types agree with the header. It
did *not* establish that the arguments are in the right order: a stub
binding `tiny_sum(a, b)` to `sum b a` compiles, links, and passes every
structural agreement in the catalogue. That is a real projection loss at
a real edge, and a differential test is the only thing that recovers it.

**But it is not the same claim as `behavior_matches`,** and merging them
would repeat the solo/pair mistake:

| | the claim | the oracle | rooted? |
| --- | --- | --- | --- |
| correspondence | the binding computes the same function as the C API | the C side, run here | in nothing — but it has an oracle without a spec |
| `behavior_matches` | the library does what the project says it does | a project-supplied expectation | in nothing, and it has no oracle |

So: **a distinct agreement**, provisionally `binding_computes_the_same`,
rather than an evaluator for `behavior_matches`.

### How to construct the test

Three shapes, cheapest first. tiny is the specimen for all of them: it
already has the two-layer structure (`Tiny_raw`, the 1:1 foreign-call
layer, and `Tiny`, the user-facing repack whose docstring says *"today
the repack is the identity modulo a rename"*).

1. **Paired drivers, shared inputs.** A C program and an OCaml program
   that each read the same input vector and print the same output
   format; compare the two outputs. Cheapest, no new vocabulary, and it
   works for `push`/`pop` because the state is internal to each run.
   ⚠ It compares TRANSCRIPTS, so it needs a canonical print — the same
   trap as `nm` output formats: *an assertion that compares tool OUTPUT
   must state the format it wants.*
2. **Algebraic laws, checked on both sides independently.**
   `pop(push(s,x)) = (s,x)`. Weaker — it does not compare the sides —
   but it catches a side that is self-consistently wrong and needs no
   shared harness. Worth having as the fallback where a C driver is
   expensive.
3. **The project's own suite, run through the binding.** Strongest and
   most expensive; needs a translation, and a failure implicates the
   translation as much as the binding. Keep for last.

**Start with 1 on tiny**, because tiny is where a controlled fault can be
injected: an argument-swap mutation in `tiny_stubs.c` is a new
mutation kind for the tiny factory, and it is invisible to every
structural agreement — which is exactly the demonstration this needs.

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
enforced it; the action is new. **The mutation comes first** — an
argument-swap in tiny that nothing currently catches is the evidence
that the agreement is worth having, and it costs one line of C.

---

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
3. **The package version is not the library version, ever.** §4.2 says
   so; the conf survey measures it (13 of 370 conf packages carry a real
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

# Project issues — open, per-project, pickable

> 2026-08-19. Split out of [`status_project.md`](status_project.md) §2/§3
> so a standalone agent can own this list. Everything here is OPEN and
> tied to a PARTICULAR project (or to one project's tooling); anything
> framework-level stays in `status_project.md`, and anything already
> fixed lives in [`../worklog/`](../worklog/).
>
> Conventions for whoever picks these up: the project layer's rules are
> in [`agreements.md`](agreements.md) and the repo CLAUDE.md — bottom-up
> increments, every increment ships a pin (`canary project-test`), and
> `make canary-test` after any edit under `src/canary/`. Live-verify with
> `canary action <project>` before calling an issue closed, and move the
> entry to the worklog rather than deleting it.

## How the entries are grouped

1. **Findings that are real and unresolved** — a run says something true
   that we have not acted on.
2. **Declaration gaps** — the spec is thinner than the project deserves;
   `canary spec-check` names most of these.
3. **Per-project chores** — small, self-contained.

---

## 1. Findings that are real and unresolved

> **torch's findings live in [`issues_torch.md`](issues_torch.md)** (split
> 2026-09-01): four problems of four different kinds, plus the
> `Declarations.yaml` recipe they produced. Canary-level findings that
> torch merely surfaced stay here — the `status` substring bug below is
> one.

### Open — the result table can show a check no world can fill (2026-09-15)

llvm's rows carry a `sip` check (the run record's `install_lib_post:sip`
column) whose every cell is, and will stay, blank. llvm derives an `install_lib` step, so
`staged_interface_preserved`'s SLOT resolves against its chain and the
column appears; but no llvm world is `Installed`, so the method's FIRING
never selects it and nothing can ever decide it.

**The two derivations answer different questions, both on purpose.** A
column comes from `ag_slot` resolved against the chain and is
world-blind — `check_cell`'s own comment says the column exists because
"the claim BELONGS here, and that is true whether or not anything has
run". An index cell (`canary checks llvm`) comes from
`m_firing mechanism lang world` and is world-aware, which is why the
index correctly reports that nothing fires at llvm's `install_lib`.

**DECIDED 2026-09-15 (user): llvm DECLARES the `Installed` point, or the
column stays blank. The firing gate is not to be relaxed.**

The temptation was to relax it, because llvm already produces both
copies. Its dev chain runs, all `ar_needs = None`
(`canary_project_llvm.ml:539-549`): `Install_lib` staging into
`build/../install`, a `Probe_lib` on the build tree writing
`probe_lib/inspect.json`, and a second `Probe_lib` on `Staged_lib`
writing `probe_lib_staged/inspect.json` — which are exactly the two
inputs `staged_interface_preserved` names. Firing on "both copies
exist" instead of "the world is `Installed`" would have decided it on
llvm today with no spec change.

It is still wrong, and the reason is the one the user gave: **it would
assert that the installed build IS the non-installed one**, which is the
very thing the agreement exists to check. A gate that fires wherever
both files happen to be present decides nothing about whether this
project's install step is a relocation, a re-link, or a re-build — it
just finds two paths. The `Installed` provision is a CLAIM the project
makes about its own staging, and nothing else can stand in for it.

So: the fix is to declare `(Installed, [Dev])` in llvm's lib universe —
after surveying what `cmake --install --component LLVM` actually does to
`libLLVM.so` here (rpath, soname, re-link?), because that survey is the
content of the claim. Until somebody does it, **leaving the column blank
is the correct state**: it says "this project has not said whether it
stages", which is true.

⚠ Note the two projects encode OPPOSITE models and that is a separate
question: sqlite gates its rows (`ar_needs = Some Installed`) so the
build-tree and staged probes never coexist in one world; llvm runs both
in every built world. Which one is right is about what an `Installed`
world MEANS for the consumer, not about this agreement.

**SECOND INSTANCE, found 2026-09-15 by the blame marks — and this one
LOSES a verdict.** The column set is computed once per project from
`covered_actions_of` (the union of every world's actions), while each
cell re-resolves `slot_in_chain` against ITS OWN row's chain. When a
project's worlds have different chains the two disagree, and the row
with the shorter chain has nowhere to put its answer:

zarith's `dependencies_provided` reports `holds x2, unavailable x2`.
`dp`'s slot resolves to `build_binding_ocaml` against the union chain,
so that is the column. Row #1 (binding **built**) has that action and
shows `no-evid` — correct, that world really did report `unavailable`.
Row #2 (binding **fetched**) has no `build_binding` at all, so
`slot_in_chain` puts its verdict at `probe_binding_ocaml` — for which
there is no column. **The `holds` is real, recorded, and invisible.**

`canary checks zarith` does report it (`decided: dependencies_provided`),
so nothing is lost overall — but the result table understates decided
coverage, which is the one thing it must not do.

The fix is small and the reason to think before taking it is that it
widens the table: derive the column set by unioning `check_cols_of_chain`
over each SCENARIO's chain rather than calling it once on the union of
actions. zarith would then gain a `probe_binding_ocaml_pre:dp` column
that only row #2 fills. Same root cause as the llvm case above, so both
should be decided together.

**The second instance is resolved on the page (2026-09-28).** The result
table (overview §1.2) shows each outcome where the agreement sits on the
chain, not at its slot, so zarith's fetched-binding row shows `dp`'s
`holds` in its build_binding frame (`design/overview.md` §6.4 step 3).
The run record's slot columns still drop it, but nothing renders them
any more. The llvm case stands as decided above.

### Open — z3's local publish cannot succeed, so the package it makes is never exercised (2026-09-15)

`canary action z3` on any built-binding world fails at `pack_binding_ocaml`:

```
[ERROR] Package z3 has no version dev.
'opam install -y z3.dev --verbose --keep-build-dir --assume-depexts' failed.
```

**Why.** opam sees a package only when `<pkg>/<pkg>.<ver>/opam` exists. The
registered `canary-local` repo holds only the template:

```
~/.opam/repo/canary-local/packages/z3/z3.dev/  →  opam.in  opam.in.tpl
```

That is *correct* — CLAUDE.md's gotcha says to keep only `opam.in`, because
a materialised `opam` file at rank 1 shadows the official package. The
`opam` file is supposed to be generated **at pack time** by
`opam config subst`.

z3's `Publish` row does not do that. It is hand-written and runs
`opam install -y z3.dev` with no `opam config subst`, no `opam repo add`,
no `opam update` — so it depends on a materialisation nobody performs.

**The helper already exists and names z3 as its intended user.**
`Canary_toolchain.opam_pack_cmd`'s own docstring: *"~preamble: shell lines
after `eval $(opam env)`, before repo add — typically
mkdir+cp+opam-config-subst for template-based packages (e.g. z3)"*.
`install_local_cmd` right above it does the full sequence. The projects
built on the opam-binding template go through that path; z3 does not.

**Why it matters beyond z3 being red.** This is the reason the published
package was never probed: not merely that no probe consumed it, but that
it was never successfully produced. `probe_binding_ocaml_opam` (added
2026-09-15) is correctly gated on `pack_binding_ocaml` and therefore
skips. The parallel-probe work is done and waits on this.

**Not fixed here deliberately.** The fix mutates opam state
(`opam repo add --rank=1`), and rank-1 shadowing is the exact hazard the
CLAUDE.md gotcha is about — worth doing with attention rather than at the
end of a long session.

### Open — a project's declared api_source is version-blind (2026-09-15)

`--strict` on sqlite fails `build_lib` in four scenarios:

```
declared_symbols_exported/declared_exports_vs_library: violated:
  sqlite3_get_clientdata,sqlite3_set_clientdata
```

The agreement is right. sqlite's built-Stable lib is **3.43.2**, chosen
deliberately as the last release *before* 3.44.0 added those two symbols
(`canary_project_sqlite.ml`, the 3.45.1 → 3.43.2 widening), and the
project's `native_api` names them.

The question this raises is general, and it is the same shape as ssl's
`dependencies_provided: violated libcrypto.so.3`: **a project declares
one API surface while its version axis realizes several.** Today the
declaration is a static property of the project spec, so a project whose
whole point is to span a symbol-adding release cannot state a
declaration that is true in both cells. Three ways out, none free:

1. scope the declaration per version point (the artifact table already
   carries the points; the `api_source` does not reach them);
2. read the declaration as a UNION and weaken the agreement to "exported
   by some declared version" — which throws away the check's teeth;
3. leave it, and treat the violation as the correct report of a real
   backward cell — which is what it is, but then `--strict` is unusable
   on any project with a mismatch axis.

Not urgent: the default (permissive) mode reports it without failing
anything, which is the behaviour every recorded run has.

### Found — tiny-full enumerates ONE world where its own docs claim six;
### the built-lib and dev-binding axes are declared in dead code (2026-08-25)

**What runs.** `canary spec tiny-full` reports *1 enumerated (1 good, 0
bad)*, and the last run executed 1 scenario. CLAUDE.md line 13 says
"6 spec-derived scenarios = {lib V:S,B:S,B:D} × {ocaml binding V:S,V:D};
binding@dev over stable lib = the forward API mismatch (undefined
`tiny_scale`), a `required_symbols_exported`-predicted xfail". Only the
first of those six exists.

**Why.** `tiny_artifact_table` (`canary_project_tiny.ml`) builds every row
with one universe cell:

```
~universe:[ (Vendored_at at, [ Stable ]) ]
```

so the product is 1 by construction. The spec that declares the missing
axes — lib `Vendored@Stable + Built@{Stable,Dev}`, ocaml binding
`{Stable,Dev}` — is `tiny_full_general_spec`, reached only through
`Canary_project_tiny.general_spec`, **which nothing reads**. Its own
docstring still claims it "is the only producer of tiny-full's scenario
list". The likely mechanism is the 2026-08-06 merge of `pr_spec` +
`pr_artifacts` into one fused table: tiny-full's rows were rebuilt from
`artifacts` × a per-KIND provider map that only knows the Vendored path,
and the Built/Dev cells did not come across.

**What is downstream of it, and now unreachable:**

- `dispatch`'s `Built_lib of channel` and `Dev_binding of { lib_built }`
  cases — no assignment can carry a Built lib or a Dev binding.
- `pr_mismatch_probes` declares the OCaml Cstubs `@Dev` `Forward` probe.
  It can never fire. **This was tiny-full's whole point** — the in-tree
  witness that the general path detects a forward API mismatch.
- The `required_symbols_exported`-predicted `tiny_scale` xfail CLAUDE.md
  advertises.

**Measured counterfactual** (2026-08-25, experiment reverted): declaring
the two axes on the live table yields **4** worlds, not 6 —
lib ∈ {`built@stable`, `vendored@stable`} × ocaml ∈ {`vendored@dev`,
`vendored@stable`}. Every `lib=built@dev` candidate is pruned, most
likely by the source-channel coupling (the source row is `vendored@stable`
and a Built lib follows its source), which is exactly the case
`tiny_full_general_spec`'s comment says should not arise because tiny's
Dev is a `-DTINY_DEV` build **flag** rather than a source version.

**Not an unnoticed break — a pinned one.** `("tiny-full", 1)` and
`~want_count:1` in `canary_projects_test.ml` both encode 1, so the pins
were moved to match rather than firing. Worth treating as the more
interesting half of the finding: the ratchet recorded the new number
instead of contesting it.

**The audit says it now** (2026-08-25). This finding is what motivated
`spec-check`'s `lib pair` / `binding pair` checks
([`status_project.md`](status_project.md) §2 item 0, DONE), and tiny-full
is the only project that warns on BOTH axes:

```
⚠  lib pair       lib: 1 point(s) [vendored@stable] — no channel pair
⚠  binding pair   binding-ocaml-cstubs: 1 [vendored@stable]; … — no consumer channel pair
```

It is exempt from the reporting-oriented checks (in-tree witness), not
from the 2×2 bar. The decision below is unchanged — the audit reports
the gap, it does not choose which way to close it.

**Pickable as:** decide whether tiny-full's general run is meant to carry
the built-lib/dev-binding axes (the docs say yes, the code says no). If
yes, move `tiny_full_general_spec`'s cells into `tiny_artifact_table`,
resolve the `built@dev` pruning, re-pin the count, and delete
`general_spec`. If no, delete `general_spec` and the unreachable
`dispatch` cases and the mismatch-probe row, and correct CLAUDE.md.
Either way `general_spec` goes.

### Found — ncurses' vendored world segfaults with a clean symbol diff;
### D6's landing is PAUSED on the contract it needs (2026-08-25)

The instance behind
[`../design/agreement/components.md`](../design/agreement/components.md) §5.5. apt 6.4 and
conda-forge 6.6 agree on the soname (`libncursesw.so.6`), on all 463
exported symbols (diff empty both ways) and on all ten `NCURSESW6_*` ELF
version nodes — and the `LD_LIBRARY_PATH` repoint crashes, because the
packagers divide the implementation differently: Debian's one `libtinfo`
IS the wide build, conda-forge ships `libtinfo` and `libtinfow` as
distinct objects. The consumer's link line was frozen in Debian's shape
(`pkg-config --libs ncursesw` → `-lncursesw -ltinfo`), so in the conda
world the loader maps conda's narrow tinfo beside the wide one the
provider's own `libncursesw` pulls. ncurses' globals exist twice.

A second, smaller one in the same world: conda-forge's `libtinfow` has
its build prefix compiled in as the terminfo path, so the relocated
prebuilt needs `TERMINFO_DIRS` — `Canary_prebuilt` knows only `libdir_of`.

**What is already done and committed** (nothing here needs redoing):

- `canary/examples/ncurses/ncurses_example.ml` — the probe, verified
  green against apt: `ncurses resolved: /usr/lib/.../libncursesw.so.6.4`.
  It uses `newterm "dumb"` over `/dev/null` rather than `initscr()`,
  which exits on a non-tty and would abort under canary's `| tee`.
- All three §3b measurements: `conf-ncurses`'s build is `pkg-config
  ncurses` (no version predicate), `curses` declares a bare
  `conf-ncurses`, and its `discover.ml` runs no version test. The gate is
  free at every step.
- Both channel points prepared: apt 6.4 installed, conda-forge 6.6 at
  `contrib/ncurses-all/prebuilt/ncurses-6.6/`. `opam install curses` =
  exactly 2 packages, as the survey predicted.

**Corrections to the survey's ncurses row, both measured:**

- The claimed depext finding is **wrong on the part that matters**.
  `conf-ncurses`'s `["ncurses-dev"] {os-family = "debian"}` resolves
  fine — `libncurses-dev` **Provides: ncurses-dev**. The real (smaller)
  finding is the *other* line: `["lib64ncurses-dev"] {os-family =
  "ubuntu"}` can never fire, because opam reports `os-family = debian`
  on Ubuntu (`os-distribution = ubuntu`), and `lib64ncurses-dev` is not
  in the archive either way. A dead line, not a broken install.
- The library HAS a version accessor — `curses_version()` returns
  `"ncurses 6.4.20240113"` — but it lives in libtinfo and `curses` does
  not bind it (no `version` anywhere in `curses.mli`). So zstd's
  two-witness form is unavailable here even though the C library offers
  one; the mapped path is the only witness, as with camlzip/zlib.

**The bug report is written** (user's call, 2026-08-25: a report rather
than a fix): [`report_ncurses_libtinfo.md`](report_ncurses_libtinfo.md)
— mechanism traced to ELF interposition (the narrow `libtinfo` wins
`cur_term`/`SP`/`_nc_globals` for every loaded object, and wide code then
reads a narrow-layout record), backtrace at `termattrs_sp`, and a
VERIFIED fix: repoint the name at the wide build and the same libraries
run green. Debian is the recommended fixer — ship `libtinfow.so.6` as an
alias and emit `-ltinfow`, strictly additive. Prior art checked: the
symptom is known folklore, the mechanism and the check-defeating property
are what is new.

**Two measurements added 2026-09-01** (registry §6.2/§6.4): the fault is
best stated as a DENOTATION failure — `libtinfo.so.6` denotes the wide
ABI on Debian and the narrow one on conda-forge, so the soname (the
identity) is the decisive artifact fact and the version-node/`TERMTYPE2`
deltas are interface detail explaining fatality. And Ubuntu today ships
NO `libtinfow`: both `ncursesw.pc` and `ncurses.pc` emit `-ltinfo`
against one object, so the recommended fix changes only `ncursesw.pc` —
at the cost that binaries built on the new Debian will not run on an
older one lacking the alias.

**Pickable as:** [`../design/agreement/components.md`](../design/agreement/components.md) §5.6 and its open work in [`../backlog.md`](../backlog.md) §51 (the finding was absorbed there 2026-09-01; `closure_shape.md`
is gone), after which the vendored world is `xfail[cN]` with a
derived reason and D6 lands at Level B. Landing it stable-only first is
possible but takes a (correct) `lib_pair` warn and throws the finding
away as a running test.

### Found — the arbipher fork cannot serve a staged consumer, and
### `assert_staged = None` let the install claim success anyway (2026-08-19)

The fork's staged world FAILS at `probe_binding_ocaml` while its Built
twin passes. Not a migration bug — a true finding, and the first one the
Installed axis produced on its own:

- Evidence: `src/api/ml/CMakeLists.txt` has **0** `install(` rules in
  `contrib/z3-all/z3` (the fork) against **3** in the official `latest`
  checkout. The fork's tree simply predates/lacks PR #10549's OCaml
  install rules — the same defect `pre-10549` was constructed to hold.
- The staged prefix confirms it: `install/lib` holds `libz3.so{,.4.15,
  .4.15.5.0}`, `cmake/`, `pkgconfig/` — and no `lib/ocaml/z3` at all.
- **The sharper half**: `install_lib` PASSED. Its completeness check is
  `assert_staged = (if official then Some [...] else None)`, so a
  non-official repo asserts NOTHING and the install reports success
  while staging an unusable package set. The defect surfaced two steps
  later, on the consumer, as an undeclared failure. That is a concrete
  argument for the staged-parity item's *completeness* bullet: derive
  `assert_staged` from the DECLARED consumer-facing surface instead of a
  hand list gated on `official` — then the install fails where the
  defect is, for every repo, and the consumer probe stops being the
  detector of last resort.

**Open question (needs a decision — the modeling is a fork in the road):**
the xfail for the same defect is keyed on `src_id = "pre-10549"` and the
install assert on `official` — two different proxies for one fact
("does this ref's install stage the OCaml package"). Options: (a) put
that fact on `source_repo` as a declared capability and key BOTH sides on
it; (b) don't enumerate a staged world for refs that can't serve one
(needs per-ref universe overrides — the universe is per-artifact today);
(c) leave it a live finding and fix the fork upstream (it is our own
fork — cherry-picking the install rules makes the world green and the
finding actionable rather than modeled away). Until this is decided the
fork's staged world stays RED in `action z3` (the default full run) —
deliberately, since silencing it would be choosing (a) by default.


### Found — `status` matches inspect files by SUBSTRING, so a variant key
### that is a prefix of another reads its neighbour's evidence (2026-08-30)

`canary_status.ml` selects a scenario's evidence files with
`String.is_substring f ~substring:vk` (two sites). torch is the first
project whose two variant keys stand in a prefix relation —
`…binding-fetched-v0.17.0` and `…binding-fetched-v0.17.0-canary1` — and
the shorter one therefore matches BOTH files. Measured on torch's first
run:

```
  ✗  …binding-fetched-v0.17.0            probe_lib_inspect  watchlist 12/12
  ✓  …binding-fetched-v0.17.0-canary1    probe_lib_inspect  watchlist 6/6
```

The watchlist has six entries. Both JSONs on disk are correct and
identical (`present: [6 symbols], missing: []`); the 12 is one row
reading two files. The binding row shows the same doubling as
`MISSING Torch,Torch`.

It is a REPORTING fault, not a run fault — the steps ran against the
right worlds and wrote the right evidence — but it is the bad kind:
it inflates a count, so it reads as more coverage rather than as an
error. Two ways to fix: match on the exact variant-key field the
filename encodes (`Canary_basic.variant_file` already builds it, so the
reader can parse rather than search), or forbid prefix-related variant
keys in the born-safe pin. The first is right; the second would ban a
legitimate naming (stock vs patched at one version).

### Open — tiny still spells its library for ONE object format, so the
### witness does not run on macOS (2026-08-26, from the Tier 1 port)

**What is fixed.** `canary/examples/tiny/c/CMakeLists.txt` guards the
version script with `if(NOT APPLE)`, because ld64 rejects the flag
outright rather than ignoring it —

```
ld: unknown options: --version-script=.../tiny.map
```

— so with it unguarded the tiny lib does not LINK on macOS and *every*
scenario built on it is unreachable, versioned or not. With the guard,
cmake produces the same shape it does on Linux: `libtiny.1.0.dylib` ←
`libtiny.1.dylib` ← `libtiny.dylib`, install_name `@rpath/libtiny.1.dylib`,
`nm -g` showing the three `_tiny_*` symbols.

**What is not.** `libtiny.so.1` is written out in ~40 places — tiny's
scenario recipes, the workspace materializer, the `soname_matches_requirement`
SONAME fixtures, the
`Dlopen` coupling, several pins. `Canary_basic.shared_lib_name` exists
now and knows both conventions (ELF puts the version AFTER the
extension, Mach-O BEFORE: `libtiny.so.1` vs `libtiny.1.dylib`), but
nothing calls it yet. Until those declarations go through it:

- `canary tiny run` (tiny1, the 22-scenario oracle) is Linux-only;
- `tiny-full`'s vendored artifacts cannot be prepared on macOS;
- `Native.Soname_bump` emits the right TOOL on either platform
  (`Canary_artifact_mutation.set_recorded_name_cmd` — `patchelf
  --set-soname` on ELF, `install_name_tool -id @rpath/…` on Mach-O) but
  is handed an ELF-shaped name, so the macOS path is not yet usable.

This is the largest single remaining piece of the macOS port and it is
self-contained: give tiny a name-building function, route the ~40 sites
through it, and decide what the fixtures assert per format.

### Open — `required_versions_exported` (symbol versioning) has no Mach-O
### referent; the nearest
### analogue is a FLOOR at library granularity (2026-08-26)

Mach-O has no symbol versioning at all. `tiny.map`, `tiny_sum@@TINY_1.0`,
the `symbol_version_floor` mutation and the `required_versions_exported`
comparator have nothing to
range over there — that is a fact about the object format, not a gap in
the witness, and guarding the version script states it.

But the *contract class* does exist on macOS, one level up. `LC_ID_DYLIB`
carries `compatibility_version`; a consumer records the value it linked
against, and dyld REFUSES to load a library whose compatibility_version
is lower. That is the same shape as `symbol_version_floor` — a
loader-enforced version floor, failing closed — at LIBRARY rather than
SYMBOL granularity. `inspect_native.py`'s Mach-O L4 branch already
extracts both `compatibility_version` and `current_version`, so the
inputs are on hand.

**The decision, not yet taken:** is this a *port* of
`required_versions_exported` at a coarser granularity, or a NEW agreement
(a `compatibility_version` floor, which would need its own name) that
happens to be the only
version-floor mechanism one of our two platforms has? The second reading
is more interesting for the manuscript: the same checking-point exists
on both platforms with different resolution, which is a statement about
what a surface theory has to be parametric in. Wiring it needs a
mutation (bump the provider's compatibility_version, or link the
consumer against a higher one) and a probe that reads dyld's refusal.

### Known — z3's system-lib resolution is Linux-only, deliberately
### un-ported (2026-08-26)

z3's FORWARD cell resolves the system libz3 with a `pkg-config` /
`dpkg -L` / `ldconfig -p` cascade over `libz3.so`, and its probes spell
`LD_LIBRARY_PATH`. The Tier 1 loader rename skipped all of it on purpose:
renaming the variable while `dpkg`, `ldconfig` and `.so` remain would
advertise a portability that cell does not have. z3 is muted; it gets
ported as a whole (brew's `pkg-config`, `otool`, `.dylib`) or not at all.

## 2. Declaration gaps

### Open — sqlite names its library's system package twice, differently

**sqlite** (found 2026-09-24, when the overview's §1 began writing each
node's declared name under its label).

Two records answer "which system package supplies the library", and
they disagree on both platforms:

| where | Linux (apt) | macOS (brew) |
| --- | --- | --- |
| `mk_prebuilt_info ~system_package_linux ~system_package_macos` (top of `canary_project_sqlite.ml`) — the store's provider | `sqlite3` | `sqlite` |
| the action-variant table's `Fetch_lib` row (`sqlite_table_rows`) | `libsqlite3-dev` | `sqlite3` |

On Ubuntu, `sqlite3` is the command-line tool, not the library:
`libsqlite3-0` ships `libsqlite3.so.0` and `libsqlite3-dev` its headers.
The provider is what the overview's names read, so sqlite's native
package shows as `sqlite3`; the hand-drawn "no package manager between"
case says `libsqlite3-0`. On Homebrew the formula is `sqlite`, with
`sqlite3` an alias.

Not investigated: which of the two each consumer reads —
`fetch_lib`'s install, the apt probe's locator, `spec-check`. Decide
which record is the declaration, derive the other from it, and let
`spec-check` refuse a disagreement — the same class as zlib's, below: two
declared answers to one question, and nothing comparing them.

### Open — zlib declares a symbol its own inspection cannot see

**zlib** (found 2026-09-17, the moment the declaration claims began
firing in Fetched worlds).

`native_api.stable_symbols` declares `zlibVersion`, deliberately and with
a comment: *"the only symbol that reports WHICH zlib answered"*.
`native_inspect_prefixes` is `[deflate; inflate; gz; crc32; adler32]`, and
`zlibVersion` matches none of them — so the recorded symbol list has 79
of the library's 102 defined symbols and `zlibVersion` is not among them.
`nm -D /usr/lib/x86_64-linux-gnu/libz.so.1` shows the library exporting
it.

**The evaluator no longer calls that a violation** — a filtered
inspection cannot convict, and it reports `inconclusive` naming the
filter (see below). But the spec is still inconsistent: zlib declares
something it has arranged not to look at. Either widen
`native_inspect_prefixes` to cover the declaration, or drop the symbol
from it and lose the identity check the comment wanted.

**The class, not the instance.** Any project whose `stable_symbols` and
`native_inspect_prefixes` disagree has this, and nothing checks that the
two are compatible. `spec-check` is where it belongs — a static
comparison of two declared lists, needing no run.

### Open — the opam-binding template's mechanism never reaches the pipeline

**cairo, libffi, zlib, zstd** (found 2026-09-16, landing pass 2).

A project can state which mechanism it binds a language through in TWO
places, and the pipeline reads one:

- `pr_binding_decls` — a `binding_decl` list. sqlite, z3, llvm, zarith,
  ssl and torch use it, and it is what
  `Canary_project_analysis.mechanism_of` reads.
- the artifact table's `a_binding lang mech` row. `Canary_opam_binding`
  fills this from its own `binding_mechanism` field and leaves
  `pr_binding_decls = []`, so those four declare a mechanism nothing in
  the pipeline sees.

Two consequences, both visible in `canary emit libffi --stage analyse`:

1. **the mechanism is the language DEFAULT.** libffi declares `Ctypes`
   on its artifact row; pass 2 reports `ocaml cstubs`.
2. **a phantom language.** With no `binding_decls`, pass 2 falls back to
   the registry-wide `[OCaml; Python]`, so libffi reports one thing its
   *Python* binding cannot carry — and it has no Python binding.

**The GATE half is closed (2026-09-24).** The template's projects also
declared their package gate (`conf-cairo`, `conf-libffi`, …) where
nothing read it, so the overview could not give their packages a
cooperation. The template now routes the gate alone through
`pr_pm_gates`, which `Canary_topology.gate_of` reads where no
`binding_decl` exists: the four are classified — "conf package" in their
apt worlds, "bridge still gates" in their vendored ones. The mechanism
is still not routed, and the two consequences above stand.

### tiny-full: two mechanisms for one language, and one step for both

**tiny-full** (found 2026-09-17, tracing how an agreement's short code
reaches the log). A sibling of the gap above and a different shape: the
declaration is read, and the pipeline has nowhere to put it.

tiny-full declares BOTH `Cext` and `Ctypes` for Python, deliberately —
it is the witness project and exercising both is its job. Its artifact
table distinguishes them (`a_binding Python Cext` vs `… Ctypes`). The
ACTION vocabulary does not: `Probe_binding of lang` and
`Build_binding of lang` carry a language and no mechanism. So

- `canary emit tiny-full --stage realize` shows ONE
  `build_binding_python` / `probe_binding_python` pair, not two;
- that is one log tag and one result-table column, so an
  `agreement_outcome` cannot say which binding produced it;
- `an_mechanisms` is an assoc list and `mechanism_for` takes the first,
  so pass 2 computes applicability for **Cext alone** and never asks
  what the Ctypes binding can carry.

Nothing is wrong in any other project — every one of them declares one
mechanism per language, which is why the log's language is enough to
recover the mechanism there. `analysis.one_mechanism_per_language` names
tiny-full as the known case and fails on a second, so this cannot spread
quietly.

The fix is a mechanism in the action vocabulary, which is a `base/`
change touching the step model, the log tags and the matrix columns —
not worth doing for one witness project, and worth knowing before a
second one wants it. Related: the provider-linkage axis in
[`../design/agreement/components.md`](../design/agreement/components.md)
§3.4 has the same shape — a real axis with no home in the action graph.

**Why it was not simply fixed when it was found.** Routing the artifact
table's mechanism into pass 2 would move libffi's OCaml side from
`Cstubs` to `Ctypes`, and Ctypes is inapplicable for
`required_symbols_exported`, `dependencies_provided`,
`soname_matches_requirement`, `required_versions_exported` and
`signatures_agree` — so **four currently GREEN cells on libffi's result
table would become `not_applicable`**. Whether that is a correction or a
misclassification is a question about `ctypes-foreign`, which is not
Python's ctypes: it DOES ship a compiled stub archive, and libffi's
`required_symbols_exported` cell holds today because a real stub was
read. So the mechanism catalogue may be what is wrong, not the
declaration.

The decision, in order: (a) is `ctypes-foreign` a `Ctypes` binding by
canary's own definition (`mi_compiles_a_stub`, `mi_consumer_records_needed`)?
(b) if yes, the four cells are wrong today and should go
`not_applicable`; if no, the template's `binding_mechanism` is
mis-declared and the fix is in the four project files. Either way pass 2
should then read ONE place. Written up at
[`../design/enumeration/stage2_analyse_spec.md`](../design/enumeration/stage2_analyse_spec.md) §8.

### Open — z3's `assert_staged` is outside the world vocabulary

Residue of the world-assertion unification (FIXED 2026-08-20, chronicled
in [`../worklog/worklog_2026_08.md`](../worklog/worklog_2026_08.md) — one
`Canary_world.t` in `base/` replaced five implementations, four of which
had failed). `assert_staged` is a `check_post` on the install step rather
than a step-world claim, so it was left alone. Folding it in wants a
`File_present` constructor and a decision on whether `check_post` and
world assertions should be one thing. Not urgent — it has a live guard
now, and the arbipher finding above is the case it would generalize.


### Found — ninja will not relink a binding whose lib bumped SONAME
### (2026-08-20, surfaced by running the pre-10549 ref)

Running z3's `pre-10549` ref for the first time failed all three of its
Built-binding cells at `build_binding_ocaml`. Two independent causes,
found in sequence:

**1. The env_guard pointed nowhere (FIXED).** z3's Build_binding row
prepends the freshly built `<build>/src/api/ml` to `CAML_LD_LIBRARY_PATH`
so z3's POST_BUILD self-check does not load the opam switch's stale
`dllz3ml.so`. It absolutised with a `$(pwd)/` prefix — correct while
`build` was relative, wrong since the per-ref build dirs of 2026-08-19
made it absolute. The guard expanded to
`<repo>//home/red/code/contrib/…`, which cannot exist. It still SET the
variable, so nothing failed loudly and the shadowing came straight back
(`unknown C primitive 'n_solver_register_on_clause'` — the very error the
guard was written for in 2026-08-13). Fixed by absolutising
conditionally; pinned as `z3.env_guard_paths` (no `//` past the root, and
the guard must still name the build tree), falsified by restoring the
unconditional prefix.

**2. A stale relink ninja would not do (WORKED AROUND, not fixed).** With
the guard corrected the error MOVED, which is how we knew the fix
mattered:

```
Fatal error: cannot load shared library dllz3ml
Reason: libz3.so.5.0: cannot open shared object file
```

`build-pre-10549/src/api/ml/dllz3ml.so` carried `NEEDED libz3.so.5.0`
while the tree's own `libz3.so` has `SONAME libz3.so.5.1` — and no
`libz3.so.5.0` exists anywhere on this machine. Both files are dated the
same minute (2026-08-17 16:49), so the binding was linked against a libz3
that tree no longer produces. **Ninja considered `dllz3ml.so` up to
date**: its recorded inputs had not changed, and a dependency's SONAME
bump is not one of the things a build system's timestamp/hash check
looks at.

Deleting the ml link outputs (`dllz3ml.so`, `libz3ml.a`, `z3ml.{cma,cmxa,a}`)
and re-running the target relinked it against `libz3.so`, and all five
pre-10549 cells then ran.

**Why this is a canary-shaped finding, not just a chore.** It is the same
failure the framework exists to detect — a binding and the library beside
it disagreeing about a soname — arriving in canary's OWN build trees, and
invisible to the build system that produced it. The generalisable fix is
the one `artifact_cache.md` §5 already proposes: a step's fingerprint
must include the IDENTITY of its input artifacts, not only its own
command text. A libz3 whose soname changed is a different input artifact;
today nothing records that, so nothing invalidates the binding built
against the old one.

**Open**: no guard exists yet. A cheap first one, in the spirit of
sqlite's `.built-<version>` stamps: after `build_binding`, assert that
every `NEEDED` entry naming the project's lib matches the soname the
tree's lib actually exports. That turns a silent stale relink into a
failed step.


### Found — every template project is HALF a 2×2, and the template
### cannot express the other half (2026-08-20)

Reading the result matrix, rows 33–40 (cairo, libffi, zlib, zstd) show
two C-lib versions against **one** OCaml binding; ssl's rows show two
bindings against **one** lib. Both are half of the 2×2 the user set as
every project's lower bound, and the halves are complementary — nothing
outside sqlite and z3 has both axes.

The mechanical part is small: ssl declares its binding axis as
`SC.Lang_pkg { versions = Some [pins] }`, while `Canary_opam_binding`
hardcodes `versions = None`
([canary_opam_binding.ml](../../../src/canary/project/canary_opam_binding.ml)),
so no template project can carry one. A field plus threading.

The part that is not small is that an opam pin is shared state. Measured
costs and the design consequences are in
[`opam_exclusive_store_issue.md` §3–5](opam_exclusive_store_issue.md); three tiers, per the
user's reading:

| tier | projects | pin cost | verdict |
| --- | --- | --- | --- |
| 1 — the package alone | zlib, cairo | 1 downgrade | **fine, could land today** — opam cannot hold two versions of a package anyway, so a swap is inherent |
| 2 — collateral rebuilds | libffi | 2 downgrades + **3 recompiles** (`llvm.19-shared`, `yaml`, `zstd`) | **both good and bad** — contamination for a clean libffi test, but each rebuild is itself a consumer/provider compatibility test we cannot enumerate. Decide what it is FOR before isolating it away (§5e) |
| 3 — the compiler | zstd | 3 removed, 37 downgraded, **157 recompiled**; `ocaml` 5.4.1 → 5.1.1 | **out** — a whole-switch compiler downgrade to run one scenario |

**Do not land a partial fix that adds the field and declares all four
pairs.** zstd's pair alone rebuilds the switch against OCaml 5.1.1.


### Open — supplying the DEV half from a prebuilt (the zstd route we
### did not need)

zstd was briefly blocked because `conf-zstd` runs
`pkg-config --atleast-version=1.3.8 libzstd` and this box had `libzstd1`
without `libzstd-dev` — no `.pc` file, no header. The user installed
`libzstd-dev` and the project landed the ordinary way (2026-08-20), so
this is no longer a blocker. What stays open is the route it pointed at:

conda-forge's `zstd` package ships `include/zstd.h` and
`lib/pkgconfig/libzstd.pc` alongside the runtime object. Pointing
`PKG_CONFIG_PATH` and the include path at a prepared prebuilt would
satisfy a conf package with **no system dev package at all** — which is
how a project would test a library version the distro does not ship in
any form, and the only way to reach a version older or newer than the
distro's on the COMPILE side rather than the load side.

Two things it needs. The prepare step currently supplies runtime only, so
a declaration would have to say which conda package half it wants (zlib
splits `libzlib` / `zlib`; zstd does not split). And it changes which
world is "stable" — the system PM is the stable point by the sourcing
rule, and a world with no system package has to say what it is instead.
Its own small arc, not a fold-in.

### Found — a vendored world can be POINTED without being CHECKED
### (2026-08-20; cairo and libffi still are)

`Canary_opam_binding.probe_names_lib` (added with the zlib landing) makes
the Vendored probe assert that the library the loader actually mapped is
inside the prebuilt's libdir. It requires the project's example to PRINT
what it resolved — zlib reads `/proc/self/maps` and prints
`zlib resolved: <path>`.

`cairo` and `libffi` declare `probe_names_lib = false`: their vendored
worlds set `LD_LIBRARY_PATH` and nothing verifies the loader obeyed.
(zlib and zstd both declare `true` — zstd's probe carries two witnesses,
the loader's mapped path AND a runtime `ZSTD_versionNumber()` call.)
cairo is the worse of the two (its two versions export identical symbol
counts, so a fallback is invisible in every verdict); libffi is the more
interesting (a `Dynamic_ffi` consumer resolves through `dlsym` at
runtime, so "which libffi answered" is the entire question).

**Fix**: teach each example to print its resolved library — the same
`/proc/self/maps` scan zlib uses, matching on `libcairo.so` /
`libffi.so` — then flip the flag. The pin
`vendored.probe_names_the_world` already covers all three projects and
will start enforcing the assert as soon as the flag turns true.


### Found — a gate can live in the BINDING's own build, and `pm_dep_gate`
### cannot express it (2026-08-20, from the conf-* survey sampling)

`mlmpfr` declares a bare `"conf-mpfr"` dependency, so by metadata alone we
would tag it `Free_with_conf`. Measured, that is wrong: its opam `build:`
compiles and RUNS an extra-source C program that reads `MPFR_VERSION_*`
from the installed header and exits nonzero when the lib is older than the
binding:

```
build: [ ["cc" "mlmpfr_compatibility_test.c" "-lmpfr" "-o" …]
         ["./mlmpfr_compatibility_test"]        ← nonzero aborts the build
         ["dune" "build" "-p" name "-j" jobs] ]
```

So mlmpfr 4.2.1 refuses to build against mpfr 4.2.0, and its opam version
tracks mpfr's (mlmpfr.4.2.1 ↔ mpfr 4.2.1). The gate is real, enforced, and
invisible to `opam show --field=depends` — the only place we look today.

**What it needs**: a `Self_check_in_build` constructor on
`Canary_binding_decl.pm_dep_gate`, whose `combination_freedom_of` is a
lower bound derived from the binding's own version. NOT added yet: no live
user until mlmpfr lands, and the codebase rule is to grow by concrete
increments.

**Why it is worth landing**: mlmpfr's forward mismatch (new binding over
old lib) is rejected by a check the upstream package already ships — a
naturally occurring xfail rather than a constructed one, which no project
in the registry has. Details and the ranked context:
[`../surveys/conf_packages.md` §G1b](../surveys/conf_packages.md).

### Open — assert that a version-bearing gate names a version-carrying conf

Measured (§G1a): 13 of 370 conf packages enforce a library version — 8 by
a pkg-config predicate (`conf-efl`, `conf-gtk3`, `conf-libblake3`,
`conf-libmd`, `conf-libuv`, `conf-openimageio`, `conf-taglib_c`,
`conf-zstd`, all floors) and 5 by feeding the opam version to a script
(`conf-llvm{,-shared,-static}`, `conf-libclang`, `conf-qt`, all
generations). Any declaration that sets `Fixed_with_conf`, or
`Bounded_with_conf { tracks_lib = true }`, over a conf package outside
that list is a declaration bug. The list is small and stable enough to
hardcode as a `project-test` invariant, and
`doc/canary/raw/conf_version_carriers.py` regenerates it; not yet wired.


### Found — spec non-uniformities (2026-08-13, `canary spec-check`)

The static checker audits the artifact table AS DECLARED. The first
report's four non-uniformities: three CLOSED by the 2026-08-13
fulfillment (pattern-A typed rows + sources, sqlite's source row +
api_source, tiny-full's `pr_api_source`); the remaining ones are
recorded here, reported as-is, NOT special-cased in checker code:

- **z3/llvm** source rows carry the STABLE repo's provider; per-channel
  (dev) source providers are the known not-yet-wired provenance
  refinement.
- **tiny-full** declares its api_source on `project_run.pr_api_source`
  (its source row is Vendored, not repo-carried) and is exempt from the
  reporting-oriented checks (in-tree witness).
- **sqlite's source row is declaration-coupled via `~follows:a_lib`**
  (the amalgamation version IS the lib's version) — source-follows-lib
  is a new axis direction, first used here.


### Open — install inspection gaps

- **`make install` template** — `cmake_install` is the only templated
  install. Autotools (`make DESTDIR=$PREFIX install`), meson, etc. need
  templates. Not yet planned in detail — to be discussed (user,
  2026-08-12).
- **Build-path leakage** — `prefix_layout_inspect_cmd` inventories the
  installed tree but doesn't check for hardcoded build-tree paths (rpath
  → `_out/`, baked `-I` in `.pc` files). A default install inspection
  should verify the installed artifact is relocatable.
- **tiny install scenarios** — tiny1 has no `Install_lib` scenario. A
  `build_install` scenario (built → installed → staged-probe chain)
  would catch install embedding build paths; a `wrong_lib_install` case
  (stale artifact or dev-lib-installed-as-stable) would test install
  identity.
- Prefix safety IS enforced: `test -n "$PREFIX"` in `cmake_install_cmd`
  refuses empty/system paths — canary never global-installs (fetch
  actions are the only intended global-store writes).

### Open — llvm's build configuration is not declared, so a cold run is
### a different build from the measured one (2026-08-30)

llvm's `Cmake_configure` row passes four flags — `-G Ninja
-DLLVM_ENABLE_BINDINGS=ON -DLLVM_BUILD_LLVM_DYLIB=ON
-DLLVM_TARGETS_TO_BUILD=X86` — and says nothing about the compiler, the
linker, or a compiler launcher. The tuned configuration (clang-23, mold,
sccache, `OPTIMIZED_TABLEGEN`, `PARALLEL_LINK_JOBS=8`) exists only in
[`../ops/llvm_build.md`](../ops/llvm_build.md), as a recipe a human runs.

The two write to the **same directory**: `mk_locals
"contrib/llvm-all/llvm-project"` takes the default `build_dir = "../build"`,
resolving to `<machine root>/contrib/llvm-all/build`. So on a WARM tree
canary's configure inherits the cached `CMAKE_C_COMPILER` /
`LLVM_USE_LINKER` / `CMAKE_*_COMPILER_LAUNCHER` and the doc's ~8 min
holds; on a COLD tree canary configures with the system defaults and it
does not. Nothing declares that dependency and nothing detects it — the
run is merely slow, which is the worst way for it to fail.

Two shapes to choose between: declare the build configuration in the spec
(accepting that a machine-specific toolchain choice becomes spec data —
the platform *pairs, never branches* rule then applies), or declare the
warm build tree as a PREREQUISITE and check for it. Same question for z3,
whose build flags ARE declared but whose toolchain is equally ambient.

### Known — CI runs the pre-A5 shape (superseded for 2 projects, 2026-08-27)

`ci_jobs` (`canary_run.ml`) derives steps from legacy `runner_spec`
values — one chain per project, not the enumerated scenario set.

**Now partly closed.** `Canary_ci` renders jobs from
`Canary_pipeline.steps_of` (one job per scenario, the same steps the
local runner executes) and `canary ci --min` writes `canary_min.yml` for
sqlite + cairo. What the legacy path cost, found while recovering CI:
`sqlite_ci_spec` passes an assignment naming only `a_lib`, so no binding
row realizes and its generated job had silently lost `fetch_binding` plus
both probes. Migrating the remaining projects is what closes this.

### Open — the pre-A5 workflow fails at every `*_summary` step

`canary_ci.yml`'s five jobs have all failed on every push since at least
2026-08-26, each at its `*_summary` step (`probe_lib_summary`,
`probe_binding_pkg_summary`). NOT the inspectors themselves: the
pipeline-rendered cairo job runs `probe_lib_inspect` and
`probe_binding_ocaml_inspect` green on the same runner image, so the
helper scripts and python work there. The fault is in the legacy spec's
summary steps — stale paths are the first suspect (the audit already
flagged `contrib/canary/opam-local-repo` vs the real
`canary/templates/opam-local-repo`).

The workflow is `workflow_dispatch`-only as of 2026-08-27 so it stops
burning ~25 minutes a push to fail the same way; it is kept because it is
the record of what once passed.

**Migration is most of the way done** (2026-08-28): three of its five
jobs — sqlite, zarith, llvm-19 — now have green pipeline-rendered twins
in `canary_min.yml`, alongside four projects it never covered. What is
left is the reason to keep the file at all:

- ~~**ssl**~~ — CLOSED 2026-08-28. `all_fetched` now reads the declared
  ORIGIN (`Vendored_at` in `pr_artifacts`) and admits an in-tree vendored
  world, which is what an example checked into the repo is; ssl is job 7
  of the eight in `canary_min.yml`.
- **z3** — deliberately out. A pin flip rebuilds libz3 (~30 min) on a
  cold runner, the same reason it is muted locally.

Only z3 is left, and it is a decision rather than a gap — so
`canary_ci.yml` and the `*_ci_spec` values it renders from can go
whenever someone confirms nothing else reads them.


### Found — zarith packs a binding nothing probes (2026-08-27)

Surfaced by the demand rule
([`../design/enumeration/stage6_realize_steps.md`](../design/enumeration/stage6_realize_steps.md) §3b).
In `lib-fetched_ocaml_binding-built-dev_binding_source_ocaml-fetched-master`,
zarith builds the binding, **packs it into the canary-local opam repo**,
and then probes the BUILD TREE:

```
ocamlfind ocamlopt -I <build> <build>/zarith.cmxa <example>   # not -package zarith
```

So `probe_binding_ocaml` depends on `build_binding_ocaml`, nothing depends
on `pack_binding_ocaml`, and the publish's result is never consumed by a
check in that world. `step.deps` is right; the world is the odd part.

Two readings, and they want different fixes:

- the world should probe the PACKED package (`-package zarith` with the
  world's libdir first on the loader path) — then the publish is under
  test and the dependency edge appears on its own; or
- the world should not pack at all — the pack belongs to a *Packed*
  binding provision, which this world does not declare.

Not decided here, and nothing acts on it: `drop_unread_fetches`
(`canary_step_builder.ml`) only removes FETCHES, so a pack is never in
its reach. The finding stands on its own — this world publishes something
no check in it consumes — rather than as a consequence of how steps are
pruned. (An earlier closure-based prune did delete the step, which is how
the finding surfaced; it was replaced 2026-08-28.)

### Open — CI pays for a cold opam switch on every job (2026-08-28)

Per-step spans, cairo job, `ubuntu-latest`:

| step | |
| --- | --- |
| `canary-setup` (setup-ocaml + apt + `opam install ocamlfind`) | 40–55s |
| `fetch_binding_ocaml` (`opam install cairo2`) | ~40s |
| `fetch_source` (partial clone, when a world needs one) | 11.6s |
| `fetch_lib` (`apt-get install`) | ~6s |
| probes + inspects | seconds |
| **job total** | ~108s |

Opam dominates; the source clone never did. A second consequence worth
keeping: a workflow's FIRST run is much slower than its later ones
because `setup-ocaml` is building its cache — a gap large enough to swamp
anything inferred from two runs.

So the CI work worth doing is caching **opam**, in
`.github/actions/canary-setup`: `setup-ocaml`'s own cache plus the
binding install. The z3 fork's canary infra caches ccache from the same
place, so the shape is known.

Explicitly LOWER priority, though it looks related: caching the contrib
source tree. It is 11.6s, and the demand rule already removed the fetch
entirely from the worlds that paid it. If it is done, key it on the
REPOSITORY rather than (repo, ref) — one repo holds every ref we track
and the worktrees share its objects, so a per-ref key shards exactly what
the worktree model exists to share.

## 3. Per-project chores

- [ ] **Spec-check warning-reconsideration pass** — zarith's
  `python_binding` ⚠ is a naming-scope artifact (the LIB is gmp, whose
  python binding is gmpy2; zarith is only the OCaml binding — an
  OCaml-focused project legitimately skips it). Revisit the warning's
  semantics when a gmp-named project (or a second zarith binding)
  lands; user confirmed leaving it for now.

- [ ] **Build-step store-hazard audit** — the z3 self-check shadowing
  class; audit other build steps' store reads (env_guard
  generalization).

- [ ] **llvm's two `probe_lib` steps write one log** — llvm's dev rows
  declare three `Probe_lib` templates: a `Raw` `llvm-config --version`
  probe, a build-tree `nm` probe, and the staged one. Only the staged one
  is renamed (`probe_lib_staged`, by its location); the other two are
  both `Build_tree`, so both write `probe_<variant>.log` into the same
  `probe_lib/` dir and the second clobbers the first. Read off the code
  (both paths reach `variant_file "probe.log"` in
  `native_lib_probe_cmd`), not yet observed on a run — the dev chain is
  an hours-long cold build. `emit llvm --stage realize --scenario
  source-fetched-latest_lib-built-dev_…` shows the duplicate step names.

**Pending (user, 2026-08-17 — AFTER active plans 3&4)**:


- [ ] **Extend tiny with the Publish** — the wrapper decl + primitive
  give tiny an opam-visible artifact when it wants one.

**Housekeeping**:


- [ ] **Upstream z3 PR** — POST_BUILD self-check env isolation
  (2-line CMake patch); per user, AFTER the 3-way repo work.

- [ ] **spec-check warns fulfillment** — the ratchet-tracked ⚠ set,
  updated 2026-08-25 when `lib_pair`/`binding_pair` landed: llvm's
  missing Publish row (`llvm.dev-shared`); the pattern-A trio + ssl's
  wrapper/python/built-binding gaps; sqlite/tiny-full's binding
  dev-source; and the new pair warns — `binding_pair` on
  cairo/libffi/zlib/zstd (a TEMPLATE gap, see §2), `lib_pair` on ssl
  (obtainable, undeclared) and tiny-full (§1). zarith's `lib_pair` is
  permanent and correct: apt already ships GMP's newest.
- [ ] **Real-world PRs** — find a bug with canary, fix it, submit
  upstream PR, link from the results page (the z3 PR above is the first
  candidate).

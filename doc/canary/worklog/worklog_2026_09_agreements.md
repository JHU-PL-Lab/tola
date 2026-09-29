# September 2026 — the agreement layer

CLAUDE.md carried this as its "Current state" section until 2026-09-29,
when that file was trimmed to what a session needs on every request. It
moved here unchanged apart from its links, which now resolve from this
directory. It chronicles the agreement layer's work from 2026-09-09 to
2026-09-17, with one note from 2026-09-28; "now" and "today" mean the day
each entry was written. The current picture is [`../status.md`](../status.md);
the overview page's September is [`worklog_2026_09.md`](worklog_2026_09.md).

---

Agreement catalogue review (2026-09-09; layout pointers updated 2026-09-17):
the Agreement overview (the overview page's §2) separates registered claims from
candidates. [agreement/README.md](../design/agreement/README.md)
explains the results; cross-cutting engineering work is in `backlog.md` §51.
`signatures_agree` compares textual signatures, `dependencies_provided`
reads one provider plus a fixed ambient list, and firing-table fixture
marks do not establish coverage of each mechanism/action cell.
The agreed seven-section layout is now the actual document order: agreement
model; common artifact foundation; language bindings (OCaml/Python, mechanisms
within each); versions; packaging/provenance; deployment/execution; registry
integration/coverage. Start with fixed artifacts available at known locations.
§2 opens with authoring questions; registry anchors follow the new numbering.
Unified action-hook integration remains
planned; `agreements_for` has test callers only (the RUN path is
`evaluate_in_context`).
The paper draft's §§4.3–4.7 now contain prose prompts following this layout;
§§4.1–4.2 were preserved verbatim at the user's request.
2026-09-11: the agreement doc now explains concrete checks directly. The
standalone surface taxonomy/correspondence sections were removed; existing
Sf labels and evidence names are confined to the implementation appendix.
§7.4 prioritizes a traceable working subset (claim → evidence → comparator →
action result), with the remaining integrations and proposals explicitly open.
The user absorbed/deleted the grammar suggestions and moved holding material
to `doc/canary/research/draft_commemt.md`.
**2026-09-12 — the naming migration + one production path.** Agreements
carry DESCRIPTIVE names (`required_symbols_exported`, `api_names_present`,
…) in code, logs, verdict markers, `--disable-agreement` and the doc; the
retired `c1`..`c9` spellings do not parse, so a stale marker or old flag
fails visibly. Solo/pair left the identity: the three declaration
comparisons are their own agreements (12 rows, was 9). A claim is now
separate from its CHECKING METHODS (`checking_method`), and evaluation
returns an `outcome` — holds / violated / unavailable / inconclusive /
not_implemented / not_applicable / disabled / error — instead of a
substring list that meant all eight at once. Diagnostic-text prediction
is a separate step (`m_diagnostics`). Cache invalidation was TARGETED:
`evaluation_schema` rides `expectation_form` for the two compat
expectations only, so agreement-derived verdicts re-ran and nothing else
did. `canary checks --catalogue` prints the generated catalogue.
`required_symbols_exported` is verified end to end through the action
path (`agreements.action_path_reports_outcomes`). The ordered backlog is
`backlog.md` §51.
**Same day, the audit pass.** ONE evaluation record per step
(`Canary_agreement.evaluate_step` → `step_evaluation`) now feeds BOTH
the report and the step's acceptance; a compat step used to evaluate
its comparators twice, once to log and once to decide. The merge of the
derived and declared evidence routes keeps the finding —
`violated` > `holds` > undecided — so it cannot lose one. A disagreement
and a confirmed expected failure are recorded separately
(`agreement_confirmed` / `agreement_unconfirmed`): a violated agreement
at a passing step stays a finding and does NOT fail the step. Audit
fixes: the three identity/version PAIR agreements no longer claim
`build_lib` (leftover from the solo/pair split — no consumer record
exists there); `firing_built_lib_only` stopped consulting the mechanism;
`load` raises instead of `exit 2`, so a bad inspection is an `error`
outcome rather than a dead process; `load_watchlist` no longer swallows
a malformed file as "no watchlist"; a `Violated []` normalizes to
`inconclusive`. Epoch `named-agreements-2`.
**THE ROUND TRIP (2026-09-12).** `canary checks <p> --observed` parses a
project's own `actions.log` (scoped to the last `run_start` marker) and
reports which agreements the last run ACTUALLY evaluated and to what
outcome. An agreement is landed when a REAL project's log shows it
`holds`/`violated` — not when a fixture passes. Gated by
`make canary-agreement-roundtrip`, inside `make canary-post-check`.
Pointing it at sqlite found three reasons every agreement had been
reporting `unavailable` there: (1) sqlite's `realize` used the template
default instead of its own `base_spec`, so its declared `api_source`
and inspectors were reachable only from the CI renderer and the run
produced NO inspect JSON; (2) the derived evidence paths spelled TINY's
filenames (framework: `inspect.json` surface + `inspect_stub.json`
stub; tiny: `inspect.json` stub + `inspect_mli.json` surface), so they
resolved on no other project; (3) sqlite inspected its binding at the
probe step, not at the install step the derivation names. All fixed:
`api_names_present` now `holds` on all 6 sqlite scenarios and flips to
`violated` when a bogus name is added to the watchlist. Evidence is now
selected by the inspector's declared `kind`, not by first-path-wins,
which is what makes listing both filename conventions safe. NEXT, one
at a time, verified from the log each time: Python `api_names_present`,
then `required_symbols_exported` (needs a stub + native inspect on
sqlite), then `signatures_agree`. The current procedure is
[`agreement/README.md`](../design/agreement/README.md).
**Agreement docs: the overview is the entry point (2026-09-17, user correction).**
The user mainly reads the Agreement overview (then on the result page, now the overview page's §2); a separate
catalogue and landing document duplicate that workflow. The eight-file split
was too complex. There are now four files: `README.md` is a short companion
to the table, `theory.md` explains the action perspective, `components.md`
keeps evidence rationale and counterexamples, and `mechanism.md` explains
applicability. Landing is a small section of the README. Do not recreate
`agreements.md`, `model.md`, `runtime.md`, or `landing.md` in this directory.
`canary checks --agreement NAME` supplies row details; `make agreement-catalogue`
now prints the live catalogue and writes no design document.

Component section numbers and registry rationale anchors are preserved.
The outcome type has eight constructors but ten labels; cstubs dependency
checks read the linked executable.

**The OCaml half of that docs-only change landed 2026-09-17**, and the
note that flagged it was right about the danger. THREE pins had gone
quiet when `agreements.md` was deleted: `agreements.catalogue_doc_is_generated`
began `if not (Sys.file_exists path) then true`, which is the right
answer for "not run from the repo root" and the wrong one for "the
document is gone"; and `doc_names_live_code` + `doc_cross_refs_resolve`
read their docs through a helper returning [None] for a missing file, so
they silently halved their coverage rather than failing. Fixed by
pointing the prose pins at the surviving four documents — which
immediately caught two unresolvable identifiers in `mechanism.md` — and
by replacing the generated-file pin with `agreements.pinned_docs_exist`,
which asserts that every document a pin reads is still there. A pin
whose input vanishes is worse than no pin, because it reports success.

⚠ **A TABLE THE TOOL GENERATES DOES NOT GET A HAND COPY** (2026-09-17).
Three did — `registry.md` §1.7, `registry.md` §7.4.1 and `landing.md`'s
"Effective" table — and all three had gone stale in the same direction,
still reporting `declared_symbols_exported` as `unavailable` for want of
a declaration months after it began deciding on sqlite and catching a
real forward-cell violation. `landing.md`'s had got as far as listing
three agreements TWICE, once as LANDED with a verdict and once as
"reported as not_applicable/unavailable". All three are gone; read
`canary checks --landing` / `--catalogue`. **8 of 13 landed** as of
2026-09-17.
**DUMMY ACTIONS** (2026-09-12, user): `Canary_step_builder.Dummy of
string` — a step that holds a place in the action graph, does no work,
and carries the reason it is empty. It exists because the graph is
where EVIDENCE attaches: a derivation looks for a binding's inspection
at the step that INSTALLS it, and CPython's stdlib `sqlite3` has no
such step. It still writes its marker ("nothing to do" ≠ "did not
run"), logs a `dummy` event, and an inspector attached to it is NOT a
dummy. NOT a stub or a TODO — it asserts that no action provisions
this artifact; if that stops being true it should become a real fetch.
List them with `canary checks --dummies`; pinned by
`steps.dummy_action_holds_a_place`. CAVEAT that cost a round: a binding
with no consumer is pruned by `drop_unread_fetches`, so the dummy needed
a Python PROBE beside it — sqlite's whole Python side (watchlist,
expect_missing, provider) had been decorative, with no `probe_binding`
entry and therefore no Python step at all.
**ONE PLACE FOR "WHAT IS <agreement>?"** (2026-09-12, user): it used to
have six answers — claim in the family module, doc anchor + enabled on
the registry row, evidence paths behind a closure, counterexamples
inside the method, fault tag wherever scenario naming needed it,
effective state only in logs. Now `canary checks --agreement NAME`
prints the COMPLETE record (subject · claim · obligation basis ·
status · fault tag · the falsifier sentence · what it is held against ·
per method: what it compares, against what, where it fires and what it
READS per world, what falsifies it, what a pass does not establish) and
appends the EFFECTIVE half from run logs. The duplicated Markdown catalogue
has been retired. `canary checks` groups the live catalogue by subject;
the overview and its candidate list remain the primary reference.
**THE THEORY DOC** (2026-09-12, user): `agreement/theory.md` — paper
material, not a description of what runs. An action `A : I₁×…×Iₙ → O`
embodies a relation `R_A` over its inputs, and RUNNING it is the only
witness that a tuple is in `R_A`; the tuple is then discarded and only
a PROJECTION survives in `O`. So an agreement = **a necessary
condition for membership in some action's input relation, decidable
from what survived** — which is why a pass can never mean
"compatible". Two losses with different ceilings: IDENTITY (which
tuple) closes exactly by recording; RELATION (what `R_A` required)
only ever converges, since completeness = re-implementing the
compiler. Three levels: edge → agreements (one per surviving
projection) → methods. §5 walks EVERY action in the catalogue with
the full-information agreement the real tool established and what
post-fact checking recovers; §6 is a generative procedure for finding
the next agreement, sanity-checked by re-deriving two known holes.
§7 states what the frame does NOT cover (set properties, cross-world
properties).
**THE DISTANCE-0 BACKLOG** (historical; current decisions in
[`agreement/README.md`](../design/agreement/README.md)): walking theory §5
against the registry gives a second backlog ordered by DISTANCE — how
far apart the two sides of a comparison are. d0 = both sides available
at one action (build tree beside staged tree; lib beside its
declaration; a re-resolvable ref); d1 = adjacent actions; d2+ =
cross-world. The original count and claim that all registered agreements
were d1 or planned are obsolete: declaration comparisons and staged-copy
comparisons can have both sides locally available. Some candidate checks
ALREADY RUN and the registry
cannot see them — the source-ref `check_post`, `install_diff_note`,
and the hand-listed pack assertions — which is the inverse of the
usual problem and means coverage is understated.
⚠ **PRECONDITION, a real bug:** the lib-side evidence path is
WORLD-BLIND. `binding_evidence_tag` reads the world's provision;
the library's path is the constant `build_lib_tag` everywhere. So a
non-Built lib's native summary is looked for where nothing writes it —
ssl/cairo/libffi/zstd/torch all write `probe_lib/inspect.json` and
nothing reads it. Third instance of the path-mismatch class. Fix =
`lib_evidence_tag` mirroring the binding's. Does not land anything
alone (the other side is missing too) but everything depends on it.
**DONE 2026-09-12 (steps 1+2):** `lib_evidence_tags` /
`lib_evidence_paths` in common — the lib-side twin of
`binding_evidence_tag`, world-aware (Fetched → probe_lib first, else
build_lib first), returning a LIST so the kind guard picks. Verified
against ssl that it lands nothing alone. AND a new 13th agreement
`staged_interface_preserved` (subject `Staging`, doc §6.1, new family
`canary_agreement_staging.ml`, new input `Staged_lib`) — the first
DISTANCE-0 agreement, both copies of the library still present. It is a
LIFT of `Canary_status.install_diff_note`, which had been running as a
status line: same fields (symbol count, soname, needed, runpath,
rpath), now registered and counted. Needs native inspections of BOTH
copies to decide.
⚠ CORRECTION to the earlier plan: only §5.4 was a liftable comparator.
§5.1 (source ref) and §5.7 (pack completeness) run as SHELL ASSERTIONS
inside commands, not comparators over evidence — registering them needs
the fact RECORDED first, so they belong in the inspector tier, not the
free one. "Already runs" ≠ "already produces evidence".
**`ag_rooted_in`** (2026-09-13, user): every agreement now states WHOSE
RULE it recovers — theory §2's central concept, in the code. 10 of 13
recover a real tool's rule (linker, C compiler, install tool, version
script); **3 do not** — `behavior_matches`, `repack_preserves_api`,
`repack_complete`. That is not a coincidence: those 3 are exactly the
ones with no evaluator. No tool enforced the relation ⇒ nothing to
re-derive ⇒ they wait on somebody to STATE a spec, not on wiring. Prefer
landing the tool-rooted ones. The catalogue also now prints WORKED
EXAMPLES per agreement, generated from the counterexample fixtures
(synthetic evidence + the outcome it reaches), so
`canary checks --agreement NAME` is the one place to read for "what is
<agreement>". **Structured 2026-09-13**
into a `rooting` record — `rt_action` / `rt_tool` / `rt_artifact` /
`rt_note` — because a sentence cannot be a column. The AGREEMENT
OVERVIEW (`make view` table 1, `canary checks --firing`) carries the
same summary live — agreement × kind × action × tool × artifact ×
status — plus the CANDIDATE table beside it for the claims that have no
methods. ⚠ There is no generated `catalogue.md` any more (2026-09-17):
the overview is the up-to-date truth and the docs maintain no second
catalogue or status list. An
action name is backticked only when `action_of_string` parses it, so a
reader can tell a step in this graph from prose standing in for a link
that ran in a world we never modelled. `landing.md` dropped its
`planned`/`fx` columns (the catalogue generates them) and keeps only
`effective`; its pin is completeness now, not the status word.
**`required_symbols_exported` IS LANDED** (2026-09-13) — 2 of 13.
`holds` ×6 on sqlite's OCaml probe, cold; falsified by injecting a bogus
name into one scenario's stub summary (that scenario alone → `violated`,
naming the symbol, recorded as `agreement_unconfirmed`: a disagreement
the action did not itself surface). Then **cairo, libffi, ssl and zarith
with NO per-project change** — the universality answer. Four fixes, and
only the first was predicted:
- an explicit `inspect` override suppressed ALL auto-generated
  summaries, not the one it replaced. Replacement is keyed on the
  output BASE NAME now;
- `Native_lib_probe` wrote a probe log and no summary, so the lib half
  existed only where a project hand-wrote the closure. It already held
  the resolved lib and the prefix;
- `lib_evidence_tags` named only `probe_lib` — the BUILD-TREE probe's
  tag. Staged and PM probes suffix themselves (`probe_lib_staged`,
  `probe_lib_apt`), so Installed/Fetched worlds looked where only a
  Built world writes;
- **`probe_binding` did not depend on `probe_lib`.** Where it decided,
  it decided by reading a file a PREVIOUS run left behind; the Fetched
  world ordered them the other way and said `unavailable`. A check that
  passes only on a warm tree is not a check — the round-trip gate now
  clears the lib probes' output too, and takes a LIST of landed names
  (`CANARY_LANDED_AGREEMENTS`).
**THE DECORATIVE DECLARATION, closed generically** (2026-09-13):
`Canary_pipeline.with_declared_facts` routes a project's `api_source`
(source repo record) and its binding's package (artifact table's
binding row) into the runner spec. Both were read only by `spec-check`
and the CI renderer, so at run time every project had
`api_source = None` and the auto summaries were tiny-only. ⚠ TWO TRAPS
this sprang, both kept: (1) a DERIVED package earns the STUB inspection
only — `binding_store_pkg` vs `binding_user_facing_pkg` are separate
fields because merging them generated an mli scan beside each project's
own, and zarith's `Zarith_version` / libffi's `Ctypes_foreign_basis`
ship with no `.mli`, so the generated summary reported missing what
ocamlobjinfo lists → a false `violated`; (2) `check_api_consistency`'s
`failwith` (build_binding without a declared `source_dir`) killed
zarith's run the moment its api_source arrived — now a warning, with
`spec-check`'s "binding dev source" item reporting the real gap.
⚠ The staging agreement names BOTH sides positionally rather than via
`lib_evidence_paths`: an Installed world's "the library" IS the staged
copy, so the derivation would have compared it against itself and held
on every relocation. It is the one agreement whose two sides are two
copies of one artifact.
Pinned: `ag_rooted_in` well-formed in `agreements.registry_complete`
(a rooted row must fill all three columns).
**DEFERRED, then done 2026-09-28 by the overview's frames** (`backlog.md`
§51): the action-unit perspective — can the result table's action
columns carry agreements BETWEEN actions? Not
blocked by the medium (`--firing` is already that grid) but by missing
data: `m_firing` is where an agreement is DETECTED; nothing typed
records where it is ROOTED. Cheap version when it earns its place: a
second mark letter (`R`) in the firing table. Also recorded there: TWO
action-column lists exist — the run record uses
`Canary_matrix.compare_column` (artifact group, then lifecycle stage),
`--firing` uses `Canary_basic.actions_of_lang`; they cannot share until
`compare_column` moves down to `base/` (layering).
**COULD DECIDE vs DID DECIDE** (2026-09-15, user). `canary checks
<project>` is the per-PROJECT cut of coverage (the landing tracker is
the per-agreement one): every action the project derives, every
agreement that fires there, and what the recorded runs decided at that
cell — then a five-class gap summary, because the five are five
different jobs. `decided` = nothing to do. `could not` = the evaluator
ran and could not conclude (`unavailable` = missing evidence, a WIRING
gap; `inconclusive` = evidence with nothing to compare, a DECLARATION
gap). `never asked` = no log line anywhere; run it cold. `stood down` =
the log says `not_applicable` where the registry now says the claim
applies, so the log predates static applicability — RE-RUN. `no
evaluator` = the three unrooted ones, waiting on a spec. `stood down`
is not theoretical: zarith showed three, and re-running it moved two
straight to `decided` — its coverage had been understated by stale log
lines. TWO BUGS THIS FOUND IN THE INDEX ITSELF, both understating: it
computed the WHOLE index with the project's first declared binding (so
sqlite reported that nothing fires at `probe_binding_python` while the
result table had five Python columns there and the log had decided
`api_names_present` twelve times), and it skipped the applicability
filter the result table already applied (listing `signatures_agree` at a
Python probe). Both fixed; pinned by
`checks.index_speaks_each_action_language`. What is NOT pinned and is
worth knowing: the index and the run record's check columns do NOT name
the same cells, by design — a column is the agreement's SLOT resolved
against the chain (world-blind: the claim BELONGS there), an index cell
is the method's FIRING in an actual world. llvm's
`install_lib_post:sip` column can never be filled because no llvm world
is Installed; recorded in `project/issues.md` §1 as a decision, not a
repair.
**THE GAP IS IN THE RESULT TABLE NOW — MARK, THEN BLAME** (2026-09-15,
user: "this information can be put on the same result table … for a
cell without a meaningful check we shall mark it with unavailable /
inconclusive / not_applicable", and "before we fix that, can we
attribute it as one thing to blame in the table, so we can see how
eager we need to fix it"). A VERDICT IS A SYMBOL, A GAP IS A WORD —
`✓ ✗` vs `no-evid` (unavailable) / `no-ref` (inconclusive) / `stale`
(not_applicable) / `off` (disabled); `·` stays a true absence ("no run
has recorded this cell"). Those five used to be ONE DOT, the same
collapse the `2/3` cell had one level down. Words rather than glyphs
because the split is the semantics: a symbol means a verdict was
reached, a word means it was not, and no pair of glyphs tells a reader
that without a key. Since a check column exists only where the claim
CAN be decided, every non-verdict cell in one is a DEFECT, so each
carries a BLAME, counted under the terminal table and per agreement in
the HTML key: `evidence` (wiring — nothing wrote the inspection),
`declaration` (spec — a declaration comparison found the declaration
empty), `version` (spec — one declared value, several version points),
`stale` (re-run), `vacuous` (nobody — both sides read, neither has
anything of this kind). EVERY BLAME IS A STATIC SCAN of the spec plus
the recorded outcome, so it can be attributed before it is fixed.
`version` is the only blame that attaches to a DECIDED cell — sqlite's
four `dse ✗` are real violations of a declaration that cannot say
"these symbols exist from 3.44", and a reader counting findings has to
be told which reds may be the spec's fault. TWO BUGS THE PIN NOW HOLDS,
both found by disbelieving the first numbers: version points were keyed
on `build_id.id`, which is `""` for an UNPINNED placement, so
Built@Stable and Built@Dev collapsed and NO project was ever
version-blind; and `inconclusive` was blamed `declaration` whatever the
comparison was, putting ten permanent `vacuous` rows on the work queue.
Pinned by `matrix.blame_is_static_and_glossed`.
**`make canary-refresh PROJECT=<p>`** (2026-09-15) clears `stale`: a
warm step logs nothing, so recorded outcomes outlive the registry that
produced them. It drops the markers of the steps that DECIDE (probes,
binding builds, staging) and re-runs; fetches and the library build
stay warm. Cleared all of zarith/cairo/libffi/zlib, and moved two
zarith claims straight to `decided`.
**ONE SOURCE OF TRUTH — `assert_binary_symbols.py` IS DELETED**
(2026-09-15, user: "I am good to delete it. Let's first use this one set
of truth from canary"). z3 (×3) and llvm (×1) answered the symbol
question with a shell script that ran `nm` over two artifacts, compared
them, and exited 0/1 — a SECOND implementation of
`required_symbols_exported`, which had been landed on five projects,
producing no evidence anyone else could read. It also carried its own
unpinned copy of the macOS nm handling, WITHOUT the underscore stripping
`inspect_native.py` has: on Mach-O both symbol sets came back empty and
`∅ ⊆ ∅` passed vacuously — the fourth silent-failure class of the macOS
section, still live in it. Two dead OCaml wrappers went with it
(`native_symbol_check_cmd`, `opam_pkg_symbol_check_cmd`, both uncalled).
NOTE WHAT THE PAIR SAID: two abandoned shell wrappers beside two live
inspectors recording the same two symbol sets — the shell form keeps
being written because it is the obvious thing to reach for, and keeps
being abandoned because nothing downstream can read what it leaves.
Replaced by `Canary_artifact_lang.stub_inspect_path_cmd`, the twin of
the opam-package form for a stub archive canary BUILDS (`ocamlfind
query` has nothing to query for a built binding — which is exactly why
z3 and llvm were the two projects still asserting by hand).
**z3 IS UNMUTED and `required_symbols_exported` decides there**: `holds`
×8 / `violated` ×2 cold, and the violation is THE FORWARD CELL
reproduced from evidence — the arbipher-HEAD binding requires 776 `Z3_`
symbols, apt's libz3 4.8.12 exports 705, **85 missing**. Two bugs found
doing it: (1) z3's `Probe_lib` inspect override resolved the library
with `pkg-config --variable=libdir z3` — the SYSTEM one — in EVERY
world, and since an explicit inspect replaces the generated one of the
same base name it was overwriting the three world-aware summaries z3's
own `Native_lib_probe` rows produce; every recorded
`probe_lib/inspect.json` said `/usr/lib/.../libz3.so` including the
worlds that build their own. Deleted; `Native_lib_probe` has emitted
that summary since 2026-09-13. (2) in the both-released world
`required_symbols_exported` is `violated` while the probe PASSES, and
both are right: the scenario declares `lib = apt` but the opam `z3`
package ships its own libz3 in `stublibs` and the loader finds that
first — which z3's spec already records as `pm_gate =
Package_builds_lib`. A declared world that the run does not realize.
**`api_names_present` LANDED ON THE PATTERN A FOUR** the same day, by
moving the template's inspect from `Probe_binding` to
`Fetch (Binding _) | Build_binding _` — the steps that PROVISION a
binding, which is where `binding_evidence_tag` looks. cairo 1→4 decided,
libffi 1→5, zlib 0→3, zarith 3→4. Nothing new is generated, which is
what keeps zarith safe (the 2026-09-13 trap was ADDING a derived mli
scan beside it). THIRD instance of the class after tiny's filenames and
probe-vs-install: the producer picks a step, the consumer derives one,
nothing makes them agree — general fix is backlog §50.
**THE PUBLISHED PACKAGE IS PROBED, IN PARALLEL** (2026-09-15, user:
"after a package is published, we shall run the same test … against the
package version z3 … because we don't know if the install package and
lib is corrected"). z3's built-binding worlds ran `opam install z3.dev`
at `Publish`, pin-checked that the switch held it, and then compiled the
example against the BUILD TREE — `-package zarith` plus `-I
<build>/src/api/ml` and an explicit `z3ml.cmxa`, dropping `-package z3`
because mixing the two gives "inconsistent assumptions". So the package
was made, its store state verified, and no probe ever asked it to work.
Now `probe_binding_ocaml` (build tree) and `probe_binding_ocaml_opam`
(the package) run as SIBLINGS — in parallel, not instead (user), because
the pair is the information: the build tree says the CODE is right, the
package says the RECIPE is, and `ocamlfind install z3 $B/src/api/ml/*`
can omit a file, ship a wrong META, or hit an unresolvable `conf-` chain,
none of which the build-tree probe can see. The dep is automatic (a
`Pm (Lang_pm _)` probe depends on `pack_binding`). Cheap, because the
local recipe skips cmake+ninja when `z3ml.cmxa` already exists — the
publish is a copy. ⚠ **BLOCKED, and the block is a real bug**
(`project/issues.md` §1): z3's Publish is hand-written and never runs
`opam config subst`, so the canary-local repo holds only `opam.in` and
`opam install z3.dev` answers "Package z3 has no version dev". The
helper exists and its docstring names z3
(`Canary_toolchain.opam_pack_cmd ~preamble`); the opam-binding template
uses that path.
**AND A BUILT BINDING'S STUB IS DECLARED, NOT OVERRIDDEN.**
`runner_spec.binding_stub_archive` (lang × glob) earns the compiled-stub
summary at `Build_binding`, which the package route cannot produce for a
binding no package installed. It goes through the AUTO channel for a
concrete reason found the hard way: `spec.inspect` hardcodes every
summary's base name to "inspect", so a stub attached through it writes
`inspect_stub_<vk>.json` and is judged against `inspect_<vk>.json` — the
evidence lands and the step fails anyway.
**`Unavailable` CARRIES A TYPED CAUSE** (2026-09-15, user: "the real fix
is to make Unavailable carry a typed cause"). It was ONE word for three
situations — the artifact's inspection absent, the project's declaration
absent, or genuinely nothing of this kind here — so a cell that needed
NOTHING read exactly like one waiting on an inspector, and `canary
result`'s blame column had to guess. The evaluators always knew and said
so in prose; the type threw it away. `unavailable_cause =
Missing_evidence | Missing_declaration | Nothing_to_check`, and the
three carry DISTINCT LABELS — `unavailable` / `undeclared` / `vacuous` —
so the log, the landing tracker and the result marks all get it at once
rather than one report learning to parse a detail string.
`Missing_evidence` keeps the old word, so nothing matching `unavailable`
changed meaning and old logs still read as what they were. NO CACHE
EPOCH: an `Unavailable` yields no prediction whichever cause it carries,
so no compat verdict moves. Marks: `no-evid` / `no-decl` / `none`.
Effect on the real count: 81 evidence → 69, vacuous 15 → 19 (sqlite
alone shed 4 false work-queue cells whose evaluator says in the same
sentence that declaring no version tags is "the truth rather than an
omission"). `undeclared` fires on NO live project cell — every project
reaching those evaluators declares its soname and c_api — and is
exercised by a counterexample fixture, which is how a path that should
stay empty stays honest. Three fixtures had to name the finer word,
which is the pin (`agreements.fixtures_execute`) doing its job.
**`probe_lib` IS STATIC, NOT A RUNTIME CHECK** (2026-09-15, user asked).
Read the command: `nm -D | grep -c <prefix>` then `test COUNT -gt 0`.
Nothing loads, nothing executes. `probe_binding` IS runtime — it links a
consumer, runs it, and greps the output for a world witness. THREE ROLES
are tangled in the two probe actions: **existence** (the artifact the
world declares is there), **inspection** (record a projection as
evidence), **execution** (load it, run it, observe). `probe_lib` has 1+2
and NO 3; `probe_binding` has all three fused in one `&&` chain — the
same fusion removed from z3. Role 1 on `probe_lib` is a degenerate
ancestor of `declared_symbols_exported` ("count > 0" is the weakest
"exports what was declared", which is landed and reads the NAMES), so
role 2 is what the step is really for. ⚠ **NOTHING EVER `dlopen`s A
LIBRARY**: it can pass every static check and fail to load (a missing
transitive NEEDED, an unresolvable RUNPATH, a version-script mismatch
the symbol table does not show). `dependencies_provided` reasons about
RECORDED dependencies and never asks the loader. That is the identity
half `theory.md` §5.9 calls missing, and what
`interposition_binds_build_target` / `denotation_stable_across_worlds`
wait on — a role-3 `probe_lib` is NEW COVERAGE, not a reclassification.
Written up at `Canary_artifact_native.native_lib_probe_cmd`.
**TWO WRITERS, ONE FILE — now loud** (2026-09-15). Summaries reach a
step by two routes: most through `attach_inspect` (which already
replaces by output base name), but a `Native_lib_probe` appends its
inspection to the probe's OWN command, so a project's explicit
`inspect` for the same action was a second step writing the same file —
last writer won, silently. `runner_spec.template_summaries` records
what a template writes; the step builder now DROPS the override with a
message. The template wins because its answer is derived from the world
and the override's is hand-written. Pinned by
`steps.template_summary_beats_override`. Zero clashes today (z3's was
the only one).
**2026-09-17 — THE RECOVERY GRID, and three directions recorded.**
`canary checks --firing` prints a SECOND grid: same action columns,
but marking **R** where the agreement is ROOTED (the tool's rule ran
there; the information was lost there) beside **D** where a method
FIRES. `◉` is both. The gap between R and D is how far the surviving
evidence had to travel, and every column between is an action that
could have dropped it. ⚠ The `lag` column is **NOT** landing.md's
DISTANCE — that one measures how far apart the two SIDES of the
comparison are. `required_symbols_exported` is distance-1 and lag-0.
Conflating them is the error the legend exists to prevent. Pinned by
`agreements.recovery_grid_matches_rooting`. The grid exists because
`ag_rooted_in` landed: the backlog's "nothing typed records where an
agreement is ROOTED" is no longer true, which is what unblocked the
deferred action-unit view.

Three directions explored and parked in
[`doc/canary/design/directions.md`](../design/directions.md)
(backlog §54), plus the provider-linkage axis in
`design/agreement/mechanism.md`
(§53). Two findings worth carrying even if the work waits:
`inspect_native.py` has extracted Mach-O's `compatibility_version`
since the macOS port and **no agreement reads it** — written evidence
with no reader, rooted in dyld's own rule, and the cheapest agreement
available; and a CORRESPONDENCE test needs no project-supplied
expectation because the C side IS the oracle, which is what makes it a
different claim from `behavior_matches` rather than an evaluator for
it.

⚠ **A VERDICT CAN STILL BE INVISIBLE** (`project/issues.md` §1, second
instance): the column set comes from `covered_actions_of` (the union of
every world's actions) while each cell re-resolves its slot against ITS
OWN row's chain. zarith's `dependencies_provided` `holds` in the
fetched-binding world, whose chain has no `build_binding` — the column
`dp` slotted into — so that verdict has nowhere to render. Same root as
the llvm case; decide both together.

**2026-09-16 — THE PIPELINE IS LINEAR, AND APPLICABILITY HAS ONE
ANSWER.** Four landings, in order.

**(1) Pass 2 finished.** `Canary_matrix.check_cols_of_chain` and
`Canary_check_index` each re-derived "which agreements apply here"; both
ask pass 2 now. Not only deduplication — each built its own
`(mechanism, declared)` pair, and the result table's was the LANGUAGE
DEFAULT while the index used the DECLARATION. Those differ wherever a
project declares a non-default mechanism (z3/llvm bind Python through
Ctypes; the default is Cext), and applicability turns on it: 5 carryable
claims against 9. Nothing in today's output moved — no project's chain
puts such a language in front of the result table — which is the point:
the same class as the 2026-09-15 Python bug, caught before it fired.
Pinned by `checks.applicability_reads_the_declaration`, which asserts
BOTH sides. `chain_applicable` folded in as `an_chains`, so the pass
table's unnumbered *(branch)* row is gone. **Renumbered**: declare(1),
analyse(2), enumerate(3), select(4), order(5), realize(6) — four doc
renames plus a citation sweep. PIN NAMES ARE NOT RENUMBERED; a `stageN`
inside a pin name is a historical label.

**(2) The action model** (`design/action_model.md`). `<action>_post` is
a trigger MOMENT, not a specification of what runs at it — the same
`nm -D` belongs at `build_lib_post`, `fetch_lib_post`,
`install_lib_post` and a `fetch_package_post` canary does not model;
only the LOCATION differs. THE JOIN that needs is pass 2's `an_touches`
(`touches` / `produced_at` / `producers_of`), pinned by
`analysis.touches_joins_actions_to_declarations`. NOTHING CONSUMES IT
YET, and the blocker is named: **three locator vocabularies** exist for
"where is the library" (typed `probe_lib_location`, `lib_locator` globs,
raw shell). Order: one locator → derive the inspection → retire the
world→tag maps → split `probe_lib`'s three roles (nothing ever
`dlopen`s a library).

**(3) The seam is drawn**: *agreement/ owns the CLAIM, enumeration/ owns
the OCCASION.* `stage6_realize_steps.md` §2b is the account of when a
check fires; `agreement/README.md` briefly explains evaluation and results;
both READMEs state the boundary the
same way. Still crossed in CODE: `binding_evidence_tag` /
`lib_evidence_tags`, which are waiting to be DERIVED from
`producers_of`, not moved.

**(4) The global CI cache is DELETED** (user). `cache-sync`, `--cache`,
`?global_cache`, and `step.cache_key` are gone. It could not produce a
hit and had not been able to since A5 (its keys came from the CI job
specs, the only `cache_project` overriders; a local run uses the
per-scenario default), was reachable only from the tiny runner, bypassed
the fingerprint/`check_post`/switch/platform gates, and was fed by a
file that never existed. The SOUND local marker cache is untouched
(`canary cache-test`, 2/2). Before an artifact cache can be built, two
things it needs do not exist: the **world's toolchain** on the key
(nothing records a compiler or a linker; the switch and the platform
already ride the fingerprint and show the shape) and a fix for
`step_identity.md`, where a step's tag depends on how many siblings it
has. Both are `design/artifact_cache.md` §4.6–4.7.

⚠ Found, recorded, NOT fixed (`project/issues.md` §2): a project can
declare its binding mechanism in TWO places and pass 2 reads one. The
opam-binding template fills the artifact table's `a_binding` row and
leaves `pr_binding_decls` empty, so cairo/libffi/zlib/zstd declare a
mechanism nothing sees — libffi declares `Ctypes` and is reported
`Cstubs`, and its phantom Python `unsuited` claim has the same cause.
Routing the artifact table in would flip four GREEN libffi cells to
`not_applicable`, and whether that is a correction depends on whether
`ctypes-foreign` (which DOES ship a compiled stub archive, unlike
Python's ctypes) is a `Ctypes` binding by the catalogue's own
predicates. A mechanism-catalogue question, not a pipeline one.

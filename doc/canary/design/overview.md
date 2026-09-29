# The overview page — how it is built, and the plan

`canary overview` writes `docs/canary/overview.html`, and `make view`
runs it. The page explains itself: its sections, its keys, the rules its
layout keeps and where each line under a node label comes from are all
on the page. This document holds what the page cannot: the code behind
each part (§1), how a run reaches it (§2), the bridges and placeholders a
recorded run is drawn with (§3), where each value comes from (§4), the
two lists that hold the drawing (§5), the plan (§6) and the pins (§7).
Read the page first.

The history — how each piece landed, the user's words at each step, and
every pin with the breaks that turned it red — is
[`../worklog/worklog_2026_09.md`](../worklog/worklog_2026_09.md). It also
keeps this document's former §6.4, the week the result table joined the
page.

## 1. Each part of the page, and the code behind it

| on the page | computed by | from |
| --- | --- | --- |
| §1's graph: 16 nodes, 21 edges, and the edges each agreement sits on | `Canary_topology` (`nodes`, `edges`, `claim_sites`) | hand-written; pins hold them to the registry and to every step the runner derives, and §6.2 derives them |
| §1's places, looks and keys | `Canary_overview_page` (`layout`, `visual_hints`, `layout_rules`) | hand-written, held by the two lists' pins (§5) |
| §1's choices, and what each draws | `Canary_overview_join`, embedded as `#joindata` | the projects' declarations, the drivers, the mechanism and cooperation catalogues |
| a recorded run on §1, and §1.2's rows | `Canary_overview_runs`, written to `overview_runs.js`, one per machine | the record (§2) |
| §1.2's columns | `Canary_frames`, embedded as `framesdata` | the graph's edges and the claim sites |
| §2, the agreement overview | `Canary_matrix.agreement_overview` | the registry; `decided` and `blame` are counted over §1.2's cells |
| §3, the census | `Canary_overview_page.claim_sites_table` | the claim sites and the registry |
| §4's tables | `Canary_pm_solo`, the mechanism catalogue, `Canary_topology.coop_catalogue`, `Canary_overview_join.cases_of` | code; their prose columns are hand-written |
| the stylesheets and scripts | `canary/overview/` (`page.css`, `results.css`, `agreements.css`, `page.js`, `results.js`), inlined by `Canary_overview_assets` | hand-written files; artifact-test's `overview.scripts_parse` runs `node --check` on the scripts |

The page's script looks answers up in the embedded data and the runs
files and decides nothing of its own, except in the five places §4 lists.

## 2. How a run reaches the page

```
canary action <project>
  realize   the world's steps, inspection steps included
  run       actions.log: each step's state, each agreement's outcome
            each step's directory: inspection files, bridge records
            -run/manifest/<world>.json: the steps it realized
  ▼
Canary_matrix.matrix_of: the record (`canary overview --json`)
  ▼
Canary_overview_runs: one view per world and binding language
  ▼
overview_runs.js, one per machine: §1 paints a view, §1.2 renders one row per view
```

**Inspections are steps.** When realize turns a world into steps, it
adds an inspection step after each step that provides an artifact the
agreements read: after a binding is installed or built, its surface and,
for a compiled binding, the symbols its stub requires
(`inspect_binding.py`, `inspect_ocaml.py`, `inspect_python.py`); at the
library's probe or after its build, its exports and identity
(`inspect_native.py`). A bridge step writes its record
(`inspect_bridge.py`). Each writes a JSON file with a `kind` into its
parent step's directory, named for the world. Which inspection steps a
world gets follows from the project's declarations (symbol prefixes,
watchlists, the binding's package) and the world's placements. The
agreements read these files first. The page reads the same ones through
one reader, `Canary_matrix.reading_of_inspection`, which turns each into
a node, a name and a count; the bridge record is the overview's alone. A
library's node is the copy its step looked at, so an installed world
names both its build tree's copy and its staged one. A file is named for
the world, not the run, so the next run of that world replaces it
(§6.4).

**The record reads what a run realized.** The runner writes each world's
steps to its manifest (`Canary_manifest`), and `matrix_of` reads it,
re-deriving from today's code only for a world no run recorded; each row
says which in `steps_from`. The manifest decodes an action against every
action the type has (`Canary_manifest.all_actions`), because
`action_of_string` does not read them all. A run through
`run_project_multi` (ssl) writes no manifest yet.

**A row of §1.2 is a chain on a machine**, because a chain — one world in
one binding language — is what §1 draws, so sqlite's ten worlds are
twenty rows. Each machine writes its own runs file from its own log and
the page loads every machine's, so one table holds both.

**Its columns are frames** (prototype A, user, 2026-09-28), because the
old columns put a world's artifacts first and then only actions, which
showed where an artifact came from but not which action consumed or
produced it. A frame is a connected group of one action family's edges;
edges with the same inputs and their products in one layer merge into
one piece; frames go by side, then flow. Four places differ from the
prototype, each because the graph says so: the capability file is not in
the fetch's frame, since shipping it is the packager's relation; headers
built from source are a frame of their own; checks sit in code order;
and the probes produce their consumer programs.

**A check shows where it sits on the chain**, not at its slot (`ag_slot`,
which only the record's columns still use). At the slot, zarith's
fetched-library rows had no column for the declaration checks every run
decides, and its built row carried five probe-check columns that stayed
empty. A cell of §1.2 is the world's worst logged verdict in the row's
language or in none, with its blame (`Canary_matrix.chain_checks`, the
row's `checks`), so no logged verdict is left out. §2's `decided` and
`blame` count those cells, one per chain: a library's verdict counts once
in each language it serves. §1's badges colour from the same cells.

**One page.** The result matrix's page, its per-machine copy and the
per-run pages retired on 2026-09-28, and nothing a run writes is copied
to `docs/` any more. The old addresses under `docs/canary/projects/` are
pointers to §1.2 (`Canary_overview_page.pointer_files`).

## 3. Bridges and placeholders

**A placeholder says what canary does not see.** `Canary_pm_action`
records, per package manager, what it does inside one of our actions that
the run does not record: apt choosing a candidate; opam planning, solving
and building. The pipeline derives a placeholder step for each beside
every fetch that is not a dummy. It does no work and logs why it is
empty: `not_yet`, with how it could be recorded, or `out_of_reach`, with
why not. The page draws it as a marker on the edges it stands for, and an
action edge that no step of ours performed but a package manager did
reads `inside` rather than `absent`.

**A binding included with its language** (2026-09-29; user: a special
case, to revisit when similar ones appear). sqlite's Python binding is
CPython's stdlib `sqlite3`, so its fetch is a dummy. `place_step` stands
that dummy on the relations the interpreter's own build and install made
(`install_lang`, `install_surf` and `link_mod`; a C extension has no stub
build of its own), and they read `included`. `resolve_lang` stays
`absent`, since nothing resolved the binding. The rule takes two facts
together: the fetch is a dummy, and the binding's declaration puts no
package manager between it and the library. `topology.every_step_has_a_place`
lists the included bindings, so a second case is met there.

**A bridge is a thing, and canary drives it.** The four decisions (user,
2026-09-23):

1. Each package manager defines its own kinds of bridge — opam's conf
   package and depext field — modeled in `Canary_bridge` apart from what
   every package manager has. The constraint stays on the gate: the
   `depends` edge.
2. A capability file belongs to the package that ships it, and is a
   source of claims, not a bridge.
3. A composition is a template assembled from the tools and instantiated
   per project, with the project's rewrites (a bundled library, a package
   that builds its own library).
4. An edge is an action when the package manager dispatches a separate,
   observable action: opam builds a conf package as a package of its own,
   so `conf_probe` is an action edge.

`Canary_bridge_driver` (`tool/`) knows which questions a conf package
answers and how to dispatch its check in a world: the predicate's own
pkg-config call, with its opam filters evaluated against `opam var`.
`inspect_bridge.py` writes the record and exits 0 (the check holds), 1
(it does not) or 3 (canary cannot dispatch it). A step that drives a
bridge carries it (`step.bridge`); `runner_spec.bridges` asks for one.
Only zarith is wired, through conf-gmp.

**The verdict is an agreement's, not the step's** (2026-09-27). The bridge
step passes whenever it writes the record. `gate_admits_the_world` reads
the record's verdict at the binding's probe, which waits for the bridge
step, so a gate that refuses the world is a finding the run reports —
`violated` in the log, ✗ in its check cell, a red badge on `conf_probe` —
rather than a failed step that stops the chain. `--strict` makes it fail
the probe, as it does for every agreement.

## 4. Where each value comes from

**The rule** (user, 2026-09-24: "Can I confirm all the data in diagrams
… are coming from either code or logs?") is stated on the page, under §1's
diagram: every value comes from code, hand-written declarations
included, or from a file a recorded run wrote, and a value asked of the
machine rendering the page (*render*) is a defect to flag, never to hide.
The platform is not a render read: it is carried (`--platform`), and a
value that depends on it says so.

**Traced end to end: the lines under the node labels.**
`Canary_overview_runs.source` carries, with each value, which of the three
it is, what was read and the function that read it. One list produces the
value and its source together, so the two cannot disagree about which
declaration answered, and the page lists every line with its source
under §1's diagram. `overview.every_drawn_line_has_a_source` holds it; its
render clause swaps the rendering machine's answers for a sentinel and
recomputes, so a render read is observed rather than re-derived.

It found one render read: the installed version of a system package
fetched with no pinned version (`Canary_matrix.sys_pkg_version`), in
twelve placements across seven projects, because the run never recorded
the version it fetched. Recording it at the fetch (§6.1 item 2,
`resolve_sys`) makes its source a run.

**Not traced yet**, in the order to take them:

1. a recorded run's edge states: the placement is code and the state is
   run, so the source to show is the log and the step tags;
2. the badges, from the log's `agreement_outcome` lines;
3. the band rules (`band_hidden`, `band_dead`), which return node ids
   without saying which clause removed a node;
4. the five rules still in the page's script — `nearest()` lets go of
   the native side's package manager first when no chain has the choice;
   `pick('m')` chooses a mechanism's only dependent package manager; a
   chosen package stays chosen only while all four choices agree with it;
   clicking a package manager off outlines nothing; `srcOf` repeats the
   route each value was looked up by. Each can move into
   `Canary_overview_join` as data;
5. §1.2's cells, which read the same views: names and counts from the
   recorded inspections, piece states from the edges, outcomes from the
   logged verdicts.

**How to trace one.** Start from the script line that writes the value,
and name the field it reads. Follow the OCaml that fills that field to a
declaration, a rule, a file under `_out`, or a process the renderer runs.
Make that function return the value with its source, from the same list:
a second function that re-derives the source can disagree with the
value. Carry the source in the data, look it up in the script by the
value's own route, list it on the page, and pin it — every shown value
has a source, a run source names a file that exists, and a render read is
found by changing the machine's answer. Break each clause once before
trusting it.

## 5. The two lists that hold the drawing

`visual_hints` holds every look §1 uses, and both of §1's keys are
rendered from it; `overview.visual_vocabulary_is_one_list` holds it to the
stylesheet — every rule owned once, every hint applied and explained, and
no two hints that can show together looking alike. `layout_rules` holds
the places, each a sentence with its reason, checked over the nodes'
places (`layout_view`) or by a named pin; `overview.layout_rules_hold`. A
new look goes into the first list and a new placement rule into the
second, or the pins fail. The coordinates in `layout` are one drawing of
the rules; a port to another framework keeps the rules, not the
coordinates. §1.2's looks are not in `visual_hints` yet: its element kinds
are the diagram's, and a table cell is a new kind.

## 6. The plan

This is the overview task's one status (user, 2026-09-29): the list
below says what is left and what each item needs, and `status.md` points
here. §6.1 to §6.4 keep the design the items refer to, under the numbers
code comments cite. How each piece landed is the worklog.

**Now: the page's source, reorganized** (user, 2026-09-29: "Let's do this
first"), in four steps, each keeping the rendered page byte-identical.
One kind of information has one home: logic in small OCaml modules, the
stylesheets and scripts in `canary/overview/`, the page's prose in a
template there with slots the generator fills, design here, history in
the worklog and the commits. The steps: (1) the stylesheets and scripts
move out, done 2026-09-29; (2) the page's prose moves into the template;
(3) `canary_overview_page.ml` splits into the diagram, the two checked
lists, the tables, the hand-drawn cases and the assembly, and §2 leaves
`canary_matrix.ml` for its own module; (4) the moved code keeps short
comments that state the concluded design (CLAUDE.md's Conventions).
**Then:** a
diagram on the page of the workflow that generates its information (user,
2026-09-29).

The list is grouped by what an item needs before it can start. Its first
open question is the order. The plan of 2026-09-28 was the rest of phase
E, then §6.2's derivations; but phase E's end state needs §6.2 step 3,
claim sites from rooting. So the question is whether A and §6.2's
derivations come before C.

**A. Decide first.** Design; no code until it is settled; in dependency
order.

1. **Targets name the diagram's nodes** (§6.1), so a member in the
   package layer (a bridge, a capability file, a package) can be named,
   and the binding splits into source, stub, module and surface. This
   unblocks `depext_names_the_provided_package` and lets §2's `sits on`
   and `where` go (§6.3).
2. **Claim sites are derived from rooting and targets** (§6.2 step 3),
   with the hand-written `claim_sites` kept as the oracle until the two
   agree. The disagreements to decide are §6.1's table:
   `dependencies_provided`, `api_names_present` and
   `gate_admits_the_world`. One consequence is visible today: zarith's
   built world decides `api_names_present` at its probe, the check's one
   site is `install_surf`, and no fetch installs a built binding's
   surface, so §1.2 hatches that cell while §2 counts it.
3. **Laws tie an agreement's kind to its place** (§6.1).
4. **A candidate is a registry row with no evaluator** (§6.1).
5. **The three other claims the bridge record carries**, a decision each:
   - `declared_gate_matches_package` compares the project's declared gate
     with the binding package's metadata. Whether a declaration held
     against a declaration is an agreement or part of the offline spec
     audit is `package_gates.md` §7.2–7.3's open question, and the
     declared constraint does not reach the evidence: the bridge step
     knows the bridge, not the bound on it.
   - `depext_names_the_provided_package` compares the bridge's mapping
     with the system package the world takes the library from. That
     package reaches no evaluator, since a provider is not evidence, and
     both members are packages, so the registry could target only `lib`,
     and the kind law rejects an admissibility claim with one target and
     no declaration. A target that names a package waits for A1.
   - `discovery_matches_link` needs the library the link resolved, which
     nothing records, since no step asks the linker or the loader (a C
     item). It also sits on `discover`, on the system side, while it
     compares across.

**B. Ready, and adds no action.**

- `canary checks --firing` still prints the old action columns, and
  §1.2's looks are not in `visual_hints` (§5).
- §2 is counted from this machine's record, while §1.2 shows every
  machine's runs file; the two differ once a second machine's rows are on
  the page.
- The ten action families with no edge have no frame, so their steps
  have no column, and a failure there would show nowhere in §1.2.
- The log: typed fields on its events; each inspection's summary logged
  once, since a later run of a world replaces its files (§2); a manifest
  for the multi-variant runner (ssl).
- `canary view`, the only way left to regenerate a run's diagrams, fails
  on zarith: its saved `run_state.json` holds
  `fetch_binding_source_ocaml`, which `action_of_string` cannot read.
  Widening that function is a change of its own, because the catalogue
  backticks an action name only when it parses.
- §6.2 step 2, edges from the catalogue, and step 4, one typed triple.
- A pin that the page's scripts parse, and one over §1.2 as rendered
  (user, 2026-09-29). No pin runs the page's JavaScript, so a syntax
  error, or a rule in the script that hides a cell, passes them all; the
  hidden cells of 2026-09-28 were found by running §1.2's script under
  node by hand. It needs node, a new tool assumption, so it belongs in
  artifact-test.
- The script's decisions move into the data (user, 2026-09-29): the five
  rules §4 lists, and §1.2's hatching of a frame the chain lacks. Then
  checking the views' JSON is checking what a reader sees.

**C. Adds an action or a step: held** (user, 2026-09-29: "Let me/us be
more patient on modification needing to add new actions"). Each gets a
written plan before it is picked up.

- **`resolve_sys` as a record**, planned 2026-09-29: apt's chosen
  candidate and the installed version, which also retires the one render
  read (§4). An inspection of `fetch_lib` runs `LC_ALL=C apt-cache
  policy <pkg>` and writes a `resolution` record into the fetch's
  directory: the package, the installed version, the candidate, and the
  version table with priorities and origins. apt's `policy` placeholder
  leaves `Canary_pm_action` in the same change. The library's placement
  text and `pkg_sys`'s line take the version from the record,
  `resolve_sys`'s tooltip says what apt chose, and
  `Canary_matrix.sys_pkg_version` goes. Pins: the render clause of
  `overview.every_drawn_line_has_a_source` flips to "nothing is asked of
  the rendering machine"; a fixture pin for a world with a record and
  one without; an artifact-test case on the command's output. Two
  choices are open, with a recommendation each: brew keeps its
  placeholder and a brew world shows no version, rather than
  `brew info --json=v2` checked only against a sample; and a world no
  run recorded shows no version, rather than the renderer's answer.
- **The other placeholders as records**, one at a time, each leaving
  `Canary_pm_action` in the change that records it: `depends` and
  `conf_probe` (opam's install output says when it built the bridge and
  ran its check: `∗ installed conf-gmp.5`), `resolve_lang` (the plan opam
  prints — the solution, though not why) and `realize_cap` (what the
  capability file declares, `pkg-config --cflags --libs`). `discover` and
  `install_lang` stay out of reach: they happen inside opam's build,
  whose log opam deletes on success.
- **Bridges beyond zarith.** cairo, libffi, zlib and zstd route their
  gates since 2026-09-24; sqlite and ssl route theirs and use pkg-config
  predicates. llvm's predicate is a script, so its record says exit 3;
  torch's depext has no check. Until each is wired, every project that
  fetches an OCaml binding shows `gatw` without a verdict.
- **The bridge check as its own step**, run before the binding is fetched
  or built.
- **The linking lift** (§6.2 step 5), the first step that changes what a
  run does.
- **A record of the library the link resolved**, which
  `discovery_matches_link` needs.

**D. Parked.** §6.3's questions, and these:

- the bridge check driven against a library the world built itself,
  which is the built case's point (sqlite has no bridge wired);
- the predicate's fallback, which the record keeps and canary does not
  run (conf-gmp's compiles a `test.c` that ships with the conf package),
  so a failing query decides nothing;
- brew's owner query and the rest on macOS, never run there;
- three findings, each recorded in the worklog: an unreached step logs
  nothing, so "blocked upstream" and "never attempted" both read
  `unrecorded`; the log's timestamps carry no zone, which matters when a
  mac record is drawn beside a WSL one; and the opam-binding template's
  vendored-library worlds declare their lib probe at `Pm (Sys_pm apt)`
  while probing the prebuilt copy, which needs a `location` constructor
  for a supplied copy, or the prebuilt declared a build tree.

### 6.1 Phase E — the rest of the bridges

The target behind this phase (user, 2026-09-27) is every agreement
categorized by the diagram. Its first step is done: where each agreement
sits is derived and shown, as a column of the agreement overview and a
grouping under it, so the diagram, that table and the run logs name the
same agreements in the same places, and the next agreement to implement
is picked from the grouping's gaps rather than by convenience. After two
or three more land, the categories are re-grouped by hand.

**The end state is one description per agreement** (user, 2026-09-28: "a
final status of this task, where all information including the kind
categories should be synced"). Today an agreement's role and its place
are stated in two modules that do not read each other. Its role is in
its family module: the kind, the subject, the basis, the rule it recovers
(R, `ag_rooted_in`), its column in the record (`ag_slot`), and per method
the second side, where it fires (D) and what it reads, whose artifacts
are its targets (`artifacts_of_input`). Its place is
`Canary_topology.claim_sites`, a hand-written list from name to edges,
from which `sitting_of` derives layers and reach. Six row laws tie the
kind to the targets, the reference, the format and the evaluator, and
`overview.agreements_sit_on_the_chain` ties the agreement overview's
`sits on` to the site. Nothing ties the site to R, the slot, the targets
or the kind. Read off the code for the eleven checked agreements
(2026-09-28):

| the site agrees with | holds for | where it does not |
| --- | --- | --- |
| R: the site's action is the rule's | 9 of 11 | `dependencies_provided`: the rule is the loader's, at `probe_binding`, and the site is `link_mod`, a build edge. `api_names_present`: the rule is the compiler's, building the application, and the site is `install_surf`, where the surface is installed |
| the slot: the same action | 10 of 11 | `api_names_present`: filed before the application's build, sited on the install |
| the targets: they are the site's ends | 10 of 11 | `gate_admits_the_world`: its site joins two packages, the bridge and the capability file, and a target can name only an artifact kind, so the registry says `lib` and `ml` |

The agreement overview's ▣ no longer shows that last gap: since §6.4 it
marks the nodes each kind of evidence describes
(`Canary_frames.nodes_of_input`), which puts `gate_admits_the_world`'s on
the bridge and the capability file. The registry's own targets are still
artifact kinds.

The kind is not checked against the site at all. Among the eleven, every
promise sits on one side and every admissibility claim but
`api_names_present` across the two, but nothing says they must. Synced
means reaching these, each with a pin:

- **The place belongs to the description.** Each site is derived from R
  and the targets, with the hand-written list kept as the oracle until
  the two agree (§6.2 step 3). The exceptions above are the first
  disagreements to decide.
- **Targets name the diagram's nodes**, so a member in the package layer
  can be named (a bridge, a capability file, a package) and the binding
  splits into source, stub, module and surface. The record keeps artifact
  kinds by projecting each node onto the artifact it is or ships. Once
  the targets are nodes, the agreement overview's `sits on` and `where`
  can go (§6.3).
- **Laws tie the kind to the place.** An admissibility claim's site joins
  its members, a promise's produces its artifact, a preservation's copies
  it, a behaviour claim's runs it. The site's action is R's wherever R is
  in this graph, and the slot's action is the site's.
- **A candidate is a registry row with no evaluator**, with the same
  fields, so landing one adds an evaluator rather than moving an entry
  from one list to another, as E2 had to.
- **The subject** stays the one free grouping, or gives way to the
  sitting when the categories are re-grouped by hand.

E2 landed on 2026-09-27: `gate_admits_the_world`
(`canary_agreement_bridge.ml`), the first registered agreement that reads
the bridge record, holds on zarith's fetched world. §3 says how it
decides, and the worklog how it landed and how it was falsified. The
work toward the end state is the list at the top of §6: its decisions
are A, and what adds an action is C.

### 6.2 Then: the page's hand-written parts, derived from the framework

The goal (user, 2026-09-23): place the framework's actions and agreements
on the layered diagram, sync the terminology, and replace the page's
placeholders with code, bottom-up, so neither side's ideas are invented to
fit the other's. Keep each hand-written part as the check until its
derivation agrees with it.

The steps keep the numbers they had in `status.md` §2.6, which code
comments cite. Done: **step 0, terminology** (claim site, consumer
program, linking lift; layer, edge and topology kept — the decisions are
in the worklog), and **step 1, actions onto edges** — each edge carries a
typed action family, and the steps with no edge are computed from the
catalogue (phase B2).

Next, in order:

2. **Edges from the catalogue.** Generate the artifact-layer edges from
   `consumes_of_action → produces_of_action` and diff them against the
   hand-written edges. Each disagreement is a page error or a catalogue
   gap, and deciding which is the work.
3. **Claim sites from rooting.** Derive each agreement's edges from
   `ag_rooted_in.rt_action` and the artifacts it reads, and diff against
   `claim_sites`. After this the agreement overview's R marks and the
   diagram's badges come from one source.
4. **One typed triple.** Reconcile `Canary_topology.t` with the dimension
   triple of [`../project/projects.md`](../project/projects.md) §1
   (native-lib origin × lib discovery × binding origin), which is a table
   with no type.
5. **The linking lift.** Derive the package-linked probe from the
   artifact-linked one — the mechanism plus static project facts, keeping
   apart a name (static information) and a resolution the package failed
   to provide (a finding) — and give `package_resolution_suffices` an
   evaluator. The first step that changes what a run does; zarith's built
   world, which packs its binding and never probes the package, is the
   concrete case.

Three mismatches a derivation will have to decide:

- **Granularity.** The catalogue has one `Binding lang` kind; the page
  splits it into stub, module and surface. The native side has a
  component list (`api_component`); the binding side has none.
- **The consumer program.** The catalogue says a probe produces nothing;
  the page draws the program as the probe's product.
- **The source fetches.** `fetch_source` and `fetch_binding_source` have
  no edge. Adding them makes a source repository a node, and canary's
  `Repo` provider sits beside `Sys_pkg` and `Lang_pkg` — which would put
  it in the package layer.

For the paper, *topology* stays, never unqualified: define it once as the
triple — who supplies the native side, what joins, who supplies the
language side — and prefer *composition topology* to a PL reader.

### 6.3 Parked

Not urgent (user, 2026-09-27):

- **An agreement placed on several edges is counted on each** — the
  library's four declaration agreements on both of its producers,
  `package_resolution_suffices` on three edges. Whether one badge should
  span them is a question about what a badge is.
- **The registry's "inapplicable" means two things**: that a mechanism
  cannot carry an agreement, and that canary has no extractor for it yet
  (`signatures_agree` for a Python C extension). The badges follow pass 2,
  so the second kind drops out of the count instead of showing hollow.
  Telling them apart needs a typed cause, as `Unavailable` got one.
- **A candidate states no applicability**, so it is counted wherever its
  edge is drawn: `compatibility_version_satisfied`, a Mach-O agreement,
  shows on ELF chains.
- **The agreement overview's `sits on` and `where` may be one view too
  many** (user, 2026-09-27). Its columns are the frames now, grouped by
  side and layer, and its ▣, R and D marks show much of what the two say.
  They are not duplicates yet: `sits on` reads the hand-written claim
  sites, while ▣, R and D come from each agreement's evidence and
  rooting, and the two can disagree (`discovery_matches_link`). Once §6.2
  step 3 derives the sites from rooting, the columns can go.

And two left open by the bridge decisions: *version transport* (which
version domain a bridge carries across — one bool today, and llvm's
`conf-llvm-shared {= 19}` is the first bridge that carries one), and
*topology names* (the template carries the name, an instance its
rewrites; to settle when a second template exists).

### 6.4 Done first: the result matrix joined this page (2026-09-28)

One page; a row per chain and machine; frames as columns; each check
where it sits; one reader per inspection; the manifest. §2 says what each
is and why. The review, the decisions, the prototypes and the six steps
are in [`../worklog/worklog_2026_09.md`](../worklog/worklog_2026_09.md)
under this heading, which is where code comments citing "§6.4 step N"
find them. What they left open is in the list at the top of §6: B, and
A2 for zarith's hatched cell. The fixes of 2026-09-29 (§2 and the badges
count §1.2's cells, sqlite's stdlib binding reads `included`, the staged
copy is named) closed the rest.

## 7. The pins

| pin | holds |
| --- | --- |
| `matrix.record_export_is_the_matrix` | the record's cells equal the matrix's, typed and dated |
| `matrix.record_carries_every_step` | each world's steps are exactly the runner's, typed as the builder typed them |
| `matrix.record_joins_edges_and_claims` | the record's edges and claims recomputed from its steps |
| `matrix.record_carries_each_worlds_chain` | each world's chain per language: sides, cooperation, what it lacks, its agreements |
| `topology.graph_matches_the_registry` | every placed agreement and edge exists; every annotation well formed |
| `topology.every_step_has_a_place` | every realized step has an edge, or a typed reason it has none; the bindings included with their language are listed |
| `topology.joins_are_distinguished` | the five kinds of join stay five, each held to the project that is its specimen |
| `overview.package_band_is_one_cooperation` | the band rules reproduce every hand-drawn case |
| `overview.chain_choices_draw_one_chain` | the choices, the packages in canary, their names, terms and cooperations |
| `overview.recorded_runs_are_an_overlay` | the runs file parses; every view names only template edges and nodes, with known words |
| `overview.recorded_views_are_named` | recorded names over declared ones, and the ratchet of names that agree with the drawings |
| `overview.overlay_words_rank_worst_first` | the order in which several steps' states merge on one edge |
| `overview.bridge_record_is_read` | the reader of the bridge record, on a fixture |
| `steps.gate_is_read_after_its_bridge_runs` | the gate fires at the probe, reads the file the bridge step writes, and the probe waits for that step |
| `frames.derive_the_confirmed_layout` | the tables' column model is the confirmed layout; every action edge in one piece, every checked agreement at each of its sites |
| `overview.one_reader_per_inspection` | one reader of an artifact's inspection; the cell, the name and the count render it; a library's node is the copy its step looked at |
| `overview.staged_copy_is_named` | an installed world's staged copy is named and counted from its own inspection, and the build tree's copy from its own |
| `overview.results_table_is_the_column_model` | §1.2 embeds the column model; its links run both ways; every outcome is the log's, and none is left out |
| `overview.agreement_counts_are_the_tables` | §2's `decided` and `blame` are §1.2's cells counted, including a verdict where no slot is; the record carries the cells; §1.2's tooltip glosses each blame |
| `overview.badges_colour_from_the_cells` | a badge's word comes from its edge's checked agreements in the words of their §1.2 cells, including a verdict where no slot is |
| `matrix.page_titles_and_agreement_overview` | the agreement overview's cells are `Canary_frames.row_marks`, with ◆ at each checked claim's sites and none for a planned one; the retired result page's address holds a pointer to §1.2, not a table |
| `manifest.records_what_a_run_realized` | the manifest's codec is total; every world round-trips; the record prefers a run's manifest to re-deriving |
| `overview.chain_absence_is_never_recorded` | what a chain lacks is never drawn, and never recorded as touched |
| `overview.placeholders_are_drawn_as_such` | filled and hollow badges against the registry's evaluators |
| `overview.badges_count_what_applies` | a badge counts pass 2's answer for the drawn mechanism; a run colours exactly what it counts |
| `overview.agreements_sit_on_the_chain` | every agreement has one claim site; the table's `sits on` is it; the grouping lists each once; no run decided an agreement without an evaluator |
| `overview.every_drawn_line_has_a_source` | every line under a node label has one source; a render read found by swapping the machine's answers (§4) |
| `overview.edge_marks_clear_the_boxes` | no edge under a source it does not join; no label or badge hidden |
| `overview.visual_vocabulary_is_one_list` | the looks: one list, held to the stylesheet (§5) |
| `overview.layout_rules_hold` | the places: every rule holds, every named pin exists (§5) |
| `overview.tables_list_what_canary_covers` | the page's §4 tables list exactly what canary has drivers and projects for |
| `overview.sections_numbered_in_order` | the page's sections are numbered 1 to n |

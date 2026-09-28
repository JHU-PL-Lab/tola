# The overview page — recorded runs on the layered chain

`canary overview` renders `docs/canary/overview.html`, and `make view`
renders it together with the result page. Its §1 draws ONE chain, from
the package managers down to the program that runs, chosen from its parts
with a panel of buttons. When the chosen chain is one canary runs, §1 also
paints what a recorded run of it did. This document says how §1 is built
today, names the two lists that keep the drawing honest, and gives the
plan from here. Read it before changing the page.

Two companions: [`overview_provenance.md`](overview_provenance.md)
inventories where every value on §1 comes from, as a map for an audit;
[`../worklog/worklog_2026_09.md`](../worklog/worklog_2026_09.md) is the
history — how each piece landed, the user's words at each step, and every
pin with the breaks that turned it red. What is open today is the short
§2.6 and §2.7 of [`../status.md`](../status.md).

The page's other sections — the agreement overview (§2), the claim census
(§3) and canary's own tables (§4) — are described where their data lives:
[`matrix.md`](matrix.md) and [`agreement/README.md`](agreement/README.md).

## 1. The chain

**Sixteen nodes, twenty-one edges**, written by hand in
`Canary_topology.nodes` and `Canary_topology.edges`. They are
placeholders, to be derived from the action catalogue (§6.2). Until then,
pins hold them to the registry and to every step the runner derives
(`topology.graph_matches_the_registry`,
`topology.every_step_has_a_place`).

**Four layers and two sides.** Top to bottom: package managers, packages,
artifacts, programs. Left and right: the system package manager's side
and the language package manager's side, read from each node's `nd_side`.
There is no third side. A bridge package is the language side's, since an
opam maintainer writes conf-gmp and opam resolves it. A capability file
is the system side's, since it ships inside the native package. The two
consumer programs sit under the side whose resolution they use.

**An edge is one relation**, and its annotation names who makes it true:
an action of ours (an action family, `Canary_action_family`, which is an
action with its language erased), someone else's rule (`Info`, drawn in
italics: the packager, the depext table, pkg-config), or, on one edge, a
claim of ours (`same_program`, carrying `package_resolution_suffices`).
One action often makes several relations true, which is why `fetch_lib`
and `fetch_binding` each label several edges. What the relation is shows
when the pointer is over the edge.

**Where things go is governed by `layout_rules`** — thirteen rules, each a
sentence with its reason and whose it is, checked over the nodes' places
(§5). The coordinates in `layout` are one drawing of those rules; a port
to another framework keeps the rules, not the coordinates.

**The badges count agreements.** `Canary_topology.claim_sites` says only
WHERE each agreement sits — a set of edges, so an end-to-end agreement can
span several. Whether an agreement is checked is the registry's answer:
`implemented` for the census, and per binding mechanism `claim_state`,
which is pass 2's `carried_slugs`. Each edge has two badges: filled for
the agreements canary checks on that relation for the chain drawn, hollow
for those only named. Both count `edge_claims` for the drawn mechanism,
and the pointer over an edge lists them by name.

**Where each agreement sits is a column of the agreement table**
(2026-09-27). The table was built before this diagram, and the target is
to categorize every agreement by it — derived first, re-grouped by hand
only once a few more agreements have landed (user). `sitting_of` reads an
agreement's claim site and gives its edges, the layers their ends lie in,
and how far it reaches: along one side's own chain, across the two
sides, or end to end over edges leading from one layer to another. The
table shows it as `sits on` and `where`, and under the table every
agreement the diagram places, candidates included, is grouped by it, each
group counting how many are placed, checked (an evaluator in the
registry) and decided (a recorded run reached holds or violated).
`canary checks --firing` prints the same grouping. On the day it landed:

| reaches | layers | placed | checked | decided |
| --- | --- | --- | --- | --- |
| system side | package/artifact | 5 | 3 | 2 |
| system side | artifact | 4 | 1 | 1 |
| language side | package | 1 | 0 | 0 |
| language side | package/artifact | 4 | 1 | 1 |
| across the sides | package | 3 | 0 | 0 |
| across the sides | artifact | 7 | 5 | 4 |
| across the sides | artifact/program | 5 | 0 | 0 |
| end to end | pm/package/program | 1 | 0 | 0 |

Checked agreements cluster where the binding meets the library; the
bridge, the running program and the end-to-end claim have none, and no
agreement sits on a package manager's resolution alone. Two agreements
have evaluators and have never been decided by a run —
`signatures_agree` and `declared_versions_exported`. And one coordinate
is not always enough: `discovery_matches_link` sits on `discover`, both of
whose ends are on the system side, while what it compares reaches the
language side.

## 2. Choosing a chain

§1's panel offers five choices: the native side's package manager, the
language side's, a binding mechanism, a cooperation, or a package in
canary.

- A **mechanism** chooses the artifact band — which artifact nodes and
  edges exist for it (`Canary_topology.artifact_variant_of`) — and the
  package manager that ships its language's bindings.
- A **cooperation** chooses the package band: what none of the worlds of
  that kind has is not drawn (`band_hidden`), and what they have but never
  exercise is greyed (`band_dead`). Chosen package managers narrow the band
  to the worlds that have them (`band_over`); a choice no world has falls
  back to the nearest one some world has, and the page says what it let
  go.
- A **package in canary** is one of the chains canary runs, the rows of
  §4.4 — one list, `Canary_overview_join.cases_of`. Choosing it sets the
  other four and names its nodes from its project's declarations
  (`declared_names`). Where nothing names a node, the package managers'
  terms stand in: ".pc file" from the PM-solo table, "conf-* package" and
  "depext field" from `Canary_bridge.kind_term`.

**Every package in canary carries a cooperation**, known before any run:
it is derived from the world's two placements and the binding package's
declared gate (`pr_binding_decls`' `pm_gate`, else `pr_pm_gates`, which
the opam-binding template fills). A world is needed, so the derivation
sits beside firing rather than in pass 2; no run is needed.

Everything a choice draws is computed in `Canary_overview_join` and
embedded in the page as `#joindata`. The page's script keeps the state
and looks answers up. Five small rules still live in the script, and are
listed for the audit in `overview_provenance.md` §3.4.

## 3. A recorded run on the chain

**The record is `canary result --json`** (`Canary_matrix`). Per world,
per binding language: every step the realize pass derives, with its typed
action, the location a probe reads, the step an inspection summarizes,
and the state and time its log line gives; `edges`, each edge with the
steps that realize it (`Canary_topology.place_step`); `claims`, each
placed agreement with its outcomes; and `chains`, one per language — the
mechanism, the two sides, the cooperation, what the chain lacks, and the
agreements that apply to it.

**The overlay** is `Canary_overview_runs.view_of_row`, written to
`docs/canary/overview_runs.js` — one file per machine, `_mac` on macOS,
loaded by a script tag and never embedded in the page. Each view gives:

- every edge a state word, worst first when several steps realize it:
  `ran`, `warm`, `xfail`, `fail`, `blocked`, `unrecorded`; `absent` where
  no step realizes an action edge; `inside` where a package manager
  established the relation inside one of our actions; `not_ours` or
  `observed` for someone else's rule, by whether the run recorded what
  that rule said; `claim` for the claim edge;
- each realized edge the agreements it counts, and its filled badge a
  word from exactly the checked ones' outcomes — `unevaluated` where a
  checked agreement has no recorded outcome;
- the nodes' names, recorded first (the inspections the world's steps
  wrote) and declared second, each saying which; the placement line; the
  nodes nothing in the run touched, dimmed; and what the chain lacks, not
  drawn at all.

**Placeholders say what canary does not see.** `Canary_pm_action` records,
per package manager, what it does inside one of our actions that the run
does not record — apt choosing a candidate, opam planning, solving and
building. The pipeline derives a placeholder step for each beside every
fetch that is not a dummy. A placeholder does no work and logs why it is
empty: `not_yet` (and how it could be recorded) or `out_of_reach` (and why
not). On the page it is a marker on the edges it stands for, and an action
edge no step of ours performs, but a package manager did, reads `inside`
rather than `absent`.

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
answers and how to dispatch its check in a world — the predicate's own
pkg-config call, its opam filters evaluated against `opam var`.
`canary/scripts/inspect_bridge.py` writes the record and exits 0 (the
check holds), 1 (it does not) or 3 (canary cannot dispatch it). A step
that drives a bridge carries it (`step.bridge`); `runner_spec.bridges`
asks for one. **Only zarith is wired**, through conf-gmp. The overview
names the bridge, the system package and the capability file from that
record, and says in one sentence per edge what the run saw.

## 4. Where each value comes from

A value on §1 comes from code — a declaration or a rule in canary — or
from a run — a file a recorded run wrote. `Canary_overview_runs.source`
carries which, with what was read and the function that read it. The
lines under the node labels are traced end to end, and the page lists
each with its source under the diagram.

**One value is neither**: the installed version of a system package
fetched with no pinned version is asked of the machine rendering the page
(`Canary_matrix.sys_pkg_version`), because the run never recorded it. The
page flags it as `render`. Recording it at the fetch step, which is the
first item of §6.1's second step, retires it.

Everything else §1 draws — which nodes and edges, a run's states and
badges, the lists under the diagram — is inventoried for audit, with the
procedure the traced part followed, in `overview_provenance.md`.

## 5. The two lists that keep the drawing honest

**`visual_hints`** — every look §1 uses: forty hints, each naming the
stylesheet rules that make it, the drawings it can show in (always, the
generic drawing, or a recorded run), its exclusive group (an edge has one
state), and its key sample and words. Both keys on the page are rendered
from the list. `overview.visual_vocabulary_is_one_list` holds it to the
stylesheet: every §1 rule belongs to exactly one hint or to the base look,
every hint's classes are applied, every hint is explained, no two key
entries share a sample, and no two hints that can show on one kind of
element at once look alike — colour, dash, width and opacity compared the
way a reader sees them.

**`layout_rules`** — the places. Each rule is a sentence, a reason and a
check: over the nodes' places and boxes (`layout_view`, which any
rendering can report, so a future drawing can be held to the same list),
or by a named pin where the rule is about what is drawn rather than
where. `overview.layout_rules_hold`.

A new look goes into the first list and a new placement rule into the
second, or the pins fail.

## 6. The plan

In order (user, 2026-09-27): finish phase E, then the derivations of
§6.2. What §6.3 parks is not urgent.

### 6.1 Phase E — the rest of the bridges

The target behind this phase (user, 2026-09-27) is every agreement
categorized by the diagram. Its first step is done: where each agreement
sits is derived and shown (§1), so the diagram, the agreement table and
the run logs name the same agreements in the same places, and the next
agreement to implement is picked from the grouping's gaps rather than
by convenience. After two or three more land, the categories are
re-grouped by hand.

1. **E2: the first agreement that reads the bridge record.**
   `gate_admits_the_world` is the cheapest: zarith's record already says
   whether conf-gmp's check held. The record also carries both sides of
   `discovery_matches_link` (pkg-config's libdir against the library the
   binding links), `depext_names_the_provided_package`, and
   `declared_gate_matches_package`. Each lands the way every agreement
   lands — a real run's log decides it — and turns a hollow badge on a
   bridge edge into a filled one. It is the first checked agreement in
   the grouping's empty row, the package layer across the sides.
2. **The easy placeholders become records**, one at a time, each leaving
   `Canary_pm_action` in the change that records it:
   - `resolve_sys`: apt's chosen candidate and the installed version
     (`apt-cache policy`), which also retires the one `render` value (§4);
   - `depends` and `conf_probe`: opam's install output says when it built
     the bridge and ran its check in this run (`∗ installed conf-gmp.5`);
   - `resolve_lang`: the plan opam prints — the solution, though not why;
   - `realize_cap`: what the capability file declares
     (`pkg-config --cflags --libs`).

   `discover` and `install_lang` stay out of reach: they happen inside
   opam's build, whose log opam deletes on success.
3. **Bridges beyond zarith.** cairo, libffi, zlib and zstd route their
   gates since 2026-09-24; sqlite and ssl route theirs and use pkg-config
   predicates. llvm's predicate is a script, so its record says exit 3;
   torch's depext has no check.
4. **Later:** the bridge check as its own step, run before the binding is
   fetched or built; the check driven against a library the world built
   itself, which is the built case's point (sqlite has no bridge wired);
   brew's owner query and the rest on macOS, never run there.

Open findings the plan should not forget, each recorded in the worklog:
an unreached step logs nothing, so "blocked upstream" and "never
attempted" both read `unrecorded`; the log's timestamps carry no zone,
which matters when a mac record is drawn beside a WSL one; and the
opam-binding template's vendored-library worlds declare their lib probe
at `Pm (Sys_pm apt)` while probing the prebuilt copy, which needs a
`location` constructor for a supplied copy, or the prebuilt declared a
build tree.

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
   `claim_sites`. After this the overview's R column and the diagram's
   badges come from one source.
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

And two left open by the bridge decisions: *version transport* (which
version domain a bridge carries across — one bool today, and llvm's
`conf-llvm-shared {= 19}` is the first bridge that carries one), and
*topology names* (the template carries the name, an instance its
rewrites; to settle when a second template exists).

## 7. The pins

| pin | holds |
| --- | --- |
| `matrix.record_export_is_the_matrix` | the record's cells equal the matrix's, typed and dated |
| `matrix.record_carries_every_step` | each world's steps are exactly the runner's, typed as the builder typed them |
| `matrix.record_joins_edges_and_claims` | the record's edges and claims recomputed from its steps |
| `matrix.record_carries_each_worlds_chain` | each world's chain per language: sides, cooperation, what it lacks, its agreements |
| `topology.graph_matches_the_registry` | every placed agreement and edge exists; every annotation well formed |
| `topology.every_step_has_a_place` | every realized step has an edge, or a typed reason it has none |
| `topology.joins_are_distinguished` | the five kinds of join stay five, each held to the project that is its specimen |
| `overview.package_band_is_one_cooperation` | the band rules reproduce every hand-drawn case |
| `overview.chain_choices_draw_one_chain` | the choices, the packages in canary, their names, terms and cooperations |
| `overview.recorded_runs_are_an_overlay` | the runs file parses; every view names only template edges and nodes, with known words |
| `overview.recorded_views_are_named` | recorded names over declared ones, and the ratchet of names that agree with the drawings |
| `overview.overlay_words_rank_worst_first` | the order in which several steps' states merge on one edge |
| `overview.bridge_record_is_read` | the reader of the bridge record, on a fixture |
| `overview.chain_absence_is_never_recorded` | what a chain lacks is never drawn, and never recorded as touched |
| `overview.placeholders_are_drawn_as_such` | filled and hollow badges against the registry's evaluators |
| `overview.badges_count_what_applies` | a badge counts pass 2's answer for the drawn mechanism; a run colours exactly what it counts |
| `overview.agreements_sit_on_the_chain` | every agreement has one claim site; the table's `sits on` is it; the grouping lists each once; no run decided an agreement without an evaluator |
| `overview.every_drawn_line_has_a_source` | every line under a node label has one source; `render` found by swapping the machine's answers |
| `overview.edge_marks_clear_the_boxes` | no edge under a source it does not join; no label or badge hidden |
| `overview.visual_vocabulary_is_one_list` | the looks: one list, held to the stylesheet (§5) |
| `overview.layout_rules_hold` | the places: every rule holds, every named pin exists (§5) |
| `overview.tables_list_what_canary_covers` | §4's tables list exactly what canary has drivers and projects for |
| `overview.sections_numbered_in_order` | the page's sections are numbered 1 to n |

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
bridge, the running program and the end-to-end claim had none, and no
agreement sits on a package manager's resolution alone. Since E2 (§6.1)
the bridge's row has one: `gate_admits_the_world`, decided on zarith. Two
agreements have evaluators and have never been decided by a run —
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

**The verdict is an agreement's, not the step's** (2026-09-27). The bridge
step passes whenever it writes the record; until then it failed on a check
that did not hold. `gate_admits_the_world` reads the record's verdict at
the binding's probe, which waits for the bridge step, so a gate that
refuses the world is a finding the run reports — `violated` in the log, ✗
in the result table's `gatw` column, a red badge on `conf_probe` — rather
than a failed step that stops the chain. `--strict` makes it fail the
probe, as it does for every agreement.

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

In order (user, 2026-09-28): first §6.4, the result matrix joining this
page; then the rest of phase E (§6.1); then the derivations of §6.2.
What §6.3 parks is not urgent.

### 6.1 Phase E — the rest of the bridges

The target behind this phase (user, 2026-09-27) is every agreement
categorized by the diagram. Its first step is done: where each agreement
sits is derived and shown (§1), so the diagram, the agreement table and
the run logs name the same agreements in the same places, and the next
agreement to implement is picked from the grouping's gaps rather than
by convenience. After two or three more land, the categories are
re-grouped by hand.

**The end state is one description per agreement** (user, 2026-09-28: "a
final status of this task, where all information including the kind
categories should be synced"). Today an agreement's role and its place
are stated in two modules that do not read each other. Its role is in
its family module: the kind, the subject, the basis, the rule it recovers
(R, `ag_rooted_in`), where the result table shows it (`ag_slot`), and per
method the second side, where it fires (D) and what it reads, whose
artifacts are its targets (▣, `artifacts_of_input`). Its place is
`Canary_topology.claim_sites`, a hand-written list from name to edges,
from which `sitting_of` derives layers and reach. Six row laws tie the
kind to the targets, the reference, the format and the evaluator, and
`overview.agreements_sit_on_the_chain` ties the table's `sits on` to the
site. Nothing ties the site to R, the slot, the targets or the kind. Read
off the code for the eleven checked agreements (2026-09-28):

| the site agrees with | holds for | where it does not |
| --- | --- | --- |
| R: the site's action is the rule's | 9 of 11 | `dependencies_provided`: the rule is the loader's, at `probe_binding`, and the site is `link_mod`, a build edge. `api_names_present`: the rule is the compiler's, building the application, and the site is `install_surf`, where the surface is installed |
| the slot: the same action | 10 of 11 | `api_names_present`: shown before the application's build, sited on the install |
| the targets: ▣ are the site's ends | 10 of 11 | `gate_admits_the_world`: its site joins two packages, the bridge and the capability file, and ▣ can name only artifacts, so it shows `lib` and `ml` |

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
  splits into source, stub, module and surface. The result table keeps
  artifact kinds by projecting each node onto the artifact it is or
  ships. The ▣ columns become node columns grouped by layer and side,
  the headers §6.3 asks about, and `sits on` and `where` fall away.
- **Laws tie the kind to the place.** An admissibility claim's site joins
  its members, a promise's produces its artifact, a preservation's copies
  it, a behaviour claim's runs it. The site's action is R's wherever R is
  in this graph, and the slot's action is the site's.
- **A candidate is a registry row with no evaluator**, with the same
  fields, so landing one adds an evaluator rather than moving an entry
  from one list to another, as E2 had to.
- **The subject** stays the one free grouping, or gives way to the
  sitting when the categories are re-grouped by hand.

1. **E2 is done (2026-09-27): `gate_admits_the_world`**
   (`canary_agreement_bridge.ml`), the first registered agreement that
   reads the bridge record and the first checked one in the grouping's
   empty row, the package layer across the sides. A real run decided it:
   it holds on zarith's fetched world. Falsified twice through the
   runner. With pkg-config blinded, the query fails and the outcome is
   `unavailable`, because conf-gmp's predicate would then compile against
   `gmp.h` and canary does not run that fallback. With the fallback taken
   out of the record, it is `violated`. Its column, `gatw`, stands in
   front of `fetch_binding_ocaml` in every world that fetches an OCaml
   binding, so eight other projects gained 23 cells that read `·` until
   their probes run cold, and `no-evid` after: the gap item 3 closes.

   The same record carries three more claims, and each needs a decision
   before it lands (found 2026-09-28):
   - `declared_gate_matches_package` compares the project's declared gate
     with the binding package's metadata. Whether a declaration held
     against a declaration is an agreement or part of the offline spec
     audit is `package_gates.md` §7.2–7.3's open question, and the
     declared constraint does not reach the evidence: the bridge step
     knows the bridge, not the bound on it.
   - `depext_names_the_provided_package` compares the bridge's mapping
     with the system package the world takes the library from. That
     package reaches no evaluator today, since a provider is not
     evidence, and both members are packages, so ▣ could show only `lib`
     and the kind law rejects an admissibility claim with one target and
     no declaration.
   - `discovery_matches_link` needs the library the link resolved, which
     nothing records, since no step asks the linker or the loader. It also
     sits on `discover`, on the system side, while it compares across.
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
   the predicate's fallback, which the record keeps and canary does not
   run (conf-gmp's compiles a `test.c` that ships with the conf package),
   so a failing query decides nothing; brew's owner query and the rest on
   macOS, never run there.

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
- **The table's `sits on` and `where` may be one view too many** (user,
  2026-09-27). They largely restate what the artifact marks (▣) and the
  action marks (R, D) imply. Headers grouping those columns by layer and
  side could say it in less width. They are not duplicates yet: `sits
  on` reads the hand-written claim sites, while ▣, R and D come from each
  agreement's methods and rooting, and the two can disagree
  (`discovery_matches_link`). Once §6.2 step 3 derives the sites from
  rooting, the columns can give way to such headers.

And two left open by the bridge decisions: *version transport* (which
version domain a bridge carries across — one bool today, and llvm's
`conf-llvm-shared {= 19}` is the first bridge that carries one), and
*topology names* (the template carries the name, an instance its
rewrites; to settle when a second template exists).

### 6.4 First: one record, several views — the result matrix joins this page

A review, not yet a decision (user, 2026-09-28: "we can also migrate the
old matrix page into the overview page … It looks like we can have two
views for the same analysis and data, and if we can index them together,
we can chain those two sources"). The user put it ahead of the next
agreement: clarify how a result is rendered from the workflow, update
the docs, then resume §6.1.

**What the workflow produces.** Part of it is static, computed from code
with no run: the worlds each project has (passes 3 to 5), each named by a
stable `code`, a digest of project and scenario; each world's steps (pass
6), typed and placed on this page's edges; each world's chain per
language; the columns a world's row can have — its actions, the check
slots its chains carry, the artifacts a check reads; and this page's
graph, bands and claim sites. The rest comes from a run: each step's
state and each agreement's outcome in `actions.log`, and the inspections
each step wrote. `Canary_matrix.matrix_of` joins the two into one record,
which `canary result --json` exports.

**The views of it today:**

| view | where | one row per | shape from | content from |
| --- | --- | --- | --- | --- |
| the result matrix | `projects/matrix.html`, one file per machine | world | the record's columns | the record's cells |
| a recorded run | §1, from `overview_runs.js`, one file per machine | world × language | this page's graph | the record's steps, edges and claims, and the inspections, read a second time |
| a chain, or a choice | §1 | chain | this page's graph | code |
| the agreement overview | §2 | agreement × firing pattern | the registry | code, with `decided` and `blame` counted from the record |
| the grouping and the census | §2 and §3 | claim site | the claim sites | code, with `decided` counted from the record |
| a run's own page | `projects/<project>/-run/result.html` | step | the step list | that run's log |

The result matrix and a recorded drawing are already two views of one
record, and they already share an index: a drawing is named by its row's
`code` and a language (`4ea4a4-ocaml`). Nothing uses the index yet.

**Where the two views part:**

1. Neither links to the other. A row does not open its drawing, and a
   drawing does not name its row.
2. A row is a world and a drawing is a world in one language, so
   sqlite's one row is two drawings.
3. The two tables order the actions differently. The matrix puts the
   library's actions first and then one block per language, each in
   lifecycle order; §2 follows the action catalogue, which puts
   `probe_lib` last.
4. Neither table shows where an action sits on the chain, although most
   actions now carry their edges here (§6.2 step 1). Most sit on one side
   and one layer. A fetch spans three: it resolves (package-manager
   layer), installs a package (package layer) and realizes its content
   (artifact layer), and the placeholder and bridge steps already split
   it along those lines. The ten action families with no edge (the source
   fetches, configure, the application's actions) need a place of their
   own.
5. The inspections are summarized twice, separately: the matrix's
   artifact cells (`Canary_matrix.inspection_of_step`) and the drawing's
   node names (`Canary_overview_runs.read_inspection`) read the same
   files.
6. A check column sits at the agreement's slot and a badge at its site —
   §6.1's end-state finding, seen from the pages.
7. The pages are styled separately: the matrix page has fixed colours and
   no dark mode, and §2 carries a copy of its table rules
   (`Canary_matrix.overview_css`, marked for clean-up).
8. The matrix is one file per machine, while this page already loads
   both machines' runs.
9. `matrix.md` still described the combined page that split on
   2026-09-23 (corrected with this review).

**The proposal: one record, one index, every view a projection of both.**

- **The row code, with a language, addresses a world everywhere.** A row
  opens its drawing in §1 (`#rec=`), a drawing names its row, and an
  agreement's row in §2 leads to its check columns in the matrix.
- **One column model for both tables, read off this page.** Each action
  column takes the side and layer of the edges its family realizes, and
  the band colour those carry here. Left to right: the system side
  (package manager, package, artifacts), the binding, the language side
  (artifacts, package, package manager), then the program. This is the
  chain as the user describes it: two package managers, two packages,
  one binding.
- **Each step's inspection summarized once**, in the record, for both the
  artifact cell and the node name.
- **The matrix as a section of this page**, below the diagram, rows
  grouped by project. A row's shape is drawn from code even for a world
  that never ran, and its cells are filled from the record — the split
  §1 already makes between a chain and a recorded run of it.

**Decisions for the user** (1 and 6 taken, 2026-09-28: one page, and the
per-run pages retire):

1. One page, or two pages linked both ways. The split was deliberate —
   `Canary_overview_page`'s header argues that a record read beside
   mechanism, with no page break, reads as mechanism — and §1's recorded
   runs have already crossed that line, each drawn over the generic
   chain and marked as a run.
2. The column order for both tables: by side and layer as above, or the
   matrix's current order.
3. A fetch: one column coloured by its side, or split into its pieces
   where the run records them.
4. Check columns: beside their action as now, or under the layer of
   their site.
5. The two machines: a section each, or one table with a machine column.
6. The per-run pages: kept and linked from each row, or retired.

**Decided for 2 to 5: prototype A** (user, 2026-09-28: "A and the rest
looks good"; shown to them the same day over
four real chains: zarith `4ea4a4-ocaml` and `614dda-ocaml`, sqlite
`e35b2b` in both languages). The user's point: today's columns put the
world's artifacts first and then only actions, so the table shows where
an artifact came from but not which action consumed or produced it.
Both prototypes make a row a chain — one world in one language, the key
§1 already draws — and colour columns by the diagram's layers.

- **Action frames**: each action shows what it consumes, the checks on
  that input, the action, what it produced and the checks on that. An
  artifact repeats, greyed, wherever it is consumed. The settings block
  goes: a row's placements become the package-manager, package and source
  cells of its frames, and §2's rows mark the same columns (▣, R, D and
  the check's own column).
- **The diagram unrolled**: every node once, each action just before
  what it produces, each check just after its site. Narrower; a reader
  must know which earlier column an action consumed.

In both: a fetch is split into its pieces (resolve, the bridge's depends
and conf_probe, realize or install), each already a step or a placeholder;
a check sits at its site. The four rows show why the site: at the slot,
zarith's fetched-library rows have no column for the declaration checks
every run decides, and its built row carries five probe-check columns
that stay `·` forever. For the two machines, a row is a chain on a
machine, with the same chain's machines adjacent. That needs no log
change, since each machine already writes its own runs file from its
own log. The log change is for history: realize writes a manifest per
run (each step's id, action, pieces, what it consumes and produces, the
checks it may evaluate and their columns), log events name a step id
with typed fields, and each inspection's summary is logged once, so a
view reads what a run realized instead of re-deriving it from today's
code.

**Then, in order, each with a pin:**

1. **The column model** — done (2026-09-28): `Canary_frames`, printed by
   `canary checks --frames`. A frame per connected group of one action
   family's edges; sibling edges (same inputs, products in one layer)
   merged into one piece; pieces in flow order; frames by side then flow;
   each agreement with an evaluator at each of its sites — a verdict
   after its site's products, a requirement before the piece that makes
   its frame's artifacts, or after its site's products when the
   requirement is a later action's. Pinned against the confirmed layout
   by `frames.derive_the_confirmed_layout`. It differs from the prototype
   in four places, each because the diagram says so: the capability file
   is not in the fetch's frame (shipping it is the packager's relation,
   not a piece of ours); headers built from source are their own frame;
   checks sit in code order; and the two probes carry their consumer
   programs as products.
2. **Each inspection summarized once**, in the views, for both a node's
   name and its summary.
3. **The table on this page**, rendered from the column model and the
   runs files, one row per chain and machine, linked both ways with §1.
4. **§2 on the same header**: ▣, R, D and ◆ in the frame columns.
5. **The old pages retire**: `matrix.html` points here, and the per-run
   pages go.
6. **The manifest**, and the record reads it.

§6.1's agreements resume after.

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
| `steps.gate_is_read_after_its_bridge_runs` | the gate fires at the probe, reads the file the bridge step writes, and the probe waits for that step |
| `frames.derive_the_confirmed_layout` | the tables' column model is the confirmed layout; every action edge in one piece, every checked agreement at each of its sites |
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

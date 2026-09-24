# Where the overview's values come from

*(2026-09-24, user: "Can I confirm all the data in diagrams, for both
generic and the real-packages, are coming from either code or logs? It
doesn't have to be pure doc generated, but you can show the relavent code
path in some place in the page. you can demonstrate one and we can ask
another session to finish or audit the rest workflows.")*

This is for the session that audits the rest. It states the rule, shows
the one workflow that has been traced end to end, lists everything else
§1 of the overview page draws together with what reading the code says
about its source, and gives the procedure the traced workflow followed.
Apart from the agreement badges, which were settled on 2026-09-24, nothing
in §3 has been confirmed yet. It is a map for the audit, not its result.

## 1. The rule

Every value §1 draws must come from one of two places:

- **code**: a declaration or a rule in canary's source, such as a project
  spec, one of the topology's tables, or a derivation over the
  enumeration. Hand-written values count. The question is whether the
  page can say where a value came from, not whether a person typed it.
- **run**: a file a recorded run wrote under `_out/canary/projects/…`,
  such as `actions.log`, a verdict marker, an inspection JSON or a bridge
  record.

A third answer exists. It is a defect to flag, never to hide:

- **render**: asked of the machine that renders the page, at the time it
  renders. Neither the code nor the run says it, so the same page
  rendered on another machine, or later, shows something else.

The platform is not a render read in this sense. It is carried (with
`--platform` or `CANARY_PLATFORM`), it is part of the run config, and it
chooses which half of a declared pair is shown: `libgmp-dev` for apt,
`gmp` for brew. A source that depends on the platform says so ("named for
this platform").

## 2. The traced workflow: the lines under the node labels

§1 writes up to two lines under a node's generic label. The first is
either a NAME (italic where the project declares it, upright where a run
recorded it) or, where no name is known, a package manager's TERM, drawn
muted. The second is a recorded world's PLACEMENT of the artifact.

| line | computed by | source |
| --- | --- | --- |
| a name, when a package in canary is chosen | `Canary_overview_runs.declared_names`, called from `Canary_overview_join.cases_of` | code: the declaration that answered, which is one of the library row's provider, the binding declaration's soname, headers, coupling or surface path, a repo record, the routed gate (`pr_pm_gates`) or the wrapper package |
| a name, in a recorded world | `recorded_names` (the inspections the world's placed steps wrote), then `declared_names` | run: the inspection's path. Otherwise code, as above |
| a name, when only a package manager is chosen | the button | code: `Canary_overview_join.pms` |
| the capability file's term | `Canary_pm_solo.table` (`ps_capability`) | code |
| the bridge package's term | `Canary_topology.bridge_terms` → `Canary_bridge.kind_term`; with no chain drawn, `Canary_bridge.kinds_defined` | code |
| a placement | `Canary_matrix.provision_choice` (the row's setting); a bridge record's line comes from `bridge_sublabels` | code; run for the bridge record; **render** for the version of a system package fetched with no pinned version |

**One list produces both the value and its source.** `declared_names`
pairs each candidate declaration with its source before `first_some`
picks one, and `sourced_names` carries the source through the merge in
which a recorded name beats a declared one. The source therefore cannot
disagree with the value about which declaration answered. Its type is
`Canary_overview_runs.source`: a kind (`Code | Run | Render`), what was
read, and the function that read it. The data carries it as `names_src`
per package in `#joindata`, as `name_sources` and `place_sources` per view
in `overview_runs.js`, and as `sources` for the generic lines. The page's
script looks each source up by the same route its value took, and lists
every line with its source under the diagram, in *Where the lines under
the node labels come from*.

**What it found.** One render read, in 12 placements across 7 projects on
the WSL machine: the library of cairo, libffi, sqlite (×4), ssl (×2),
zarith (×2), zlib and zstd, each fetched from apt. The provider declares
the package and no `version_tag`, so `Canary_matrix.fetched_note` asks
`sys_pkg_version`, meaning this machine's apt or brew, when the page is
rendered. The run never recorded the version it fetched. That is
[`status.md`](../status.md) §2.7 finding 2, which is now visible on the
page instead of only in the plan. The fix is to record the installed
version at the fetch step, which is phase E's `resolve_sys` evidence, and
read it from there. The placement's source then becomes run. A smaller
defect sits beside it: the display strips a Debian revision but not an
epoch (`2:6.3.0+dfsg`).

**Pinned** by `overview.every_drawn_line_has_a_source`:

- a view's names and placements have exactly one source each;
- a recorded name cites a file that exists, and a declared name cites
  code;
- every §1 package's names cite code;
- the generic lines' four sources cite code;
- the page has the list and every lookup;
- **the render flag is observed, not re-derived.** The pin replaces each
  answer the rendering machine gave, in `Canary_matrix.sys_pkg_versions`,
  with a sentinel and recomputes everything. A placement must be flagged
  render exactly where the sentinel appears in its text. The memo is
  cleared afterwards, so no later pin sees the sentinel. A check that
  repeated the flag's own condition would agree with any bug in that
  condition.

Each clause was falsified once: dropping the render flag, citing a
declared name as run, and citing a file the run did not write all fail
the pin.

**What the pin does not reach.** It checks only that the script's
lookups are present in the page. That the list matches what is drawn was
checked in headless Chromium for three states: the default generic
drawing, apt and pip chosen alone, and zarith's built package with its
recorded world. That check is not a pin.

## 3. Everything else §1 draws, to audit

This section is grouped by where each value is computed. The source
column is what reading the code says today. The audit confirms it, and
where it holds, gives the value a source the page shows, as §2 did.

### 3.1 The template, written into the page by OCaml

| what | from | believed source | to check |
| --- | --- | --- | --- |
| node ids, labels, layers | `Canary_topology.nodes` | code, hand-written | |
| positions, and where each edge's label and badges sit | the layout table and `label_at` in `Canary_overview_page` | code, hand-written | already pinned: one row per layer, no box overlaps another, each source beside its package's column, and no label or badge hidden (`overview.edge_marks_clear_the_boxes`) |
| edges: ends, annotation, description | `Canary_topology.edges` | code, hand-written | `topology.graph_matches_the_registry` holds the ends and the action coverage |
| agreement badges and where they sit | `Canary_topology.claim_sites` (where, hand-written); the registry (whether checked) | code | Settled on 2026-09-24. The hand-written `cs_implemented` flag was wrong for three agreements and has been removed. `implemented` and `claim_state` now ask the registry, and the badges are counted per drawing ([`status.md`](../status.md) §2.7) |
| placeholder slots | one per edge | code | |
| every look, and the keys that explain them | `Canary_overview_page.visual_hints` (the stylesheet rules each look is made of, and its key entry) | code, hand-written | Settled on 2026-09-24. Both keys are rendered from the list, and `overview.visual_vocabulary_is_one_list` holds it to the stylesheet |

### 3.2 A choice's drawing: `#joindata`, computed by `Canary_overview_join`

| what | from | believed source |
| --- | --- | --- |
| the package-manager buttons | `Canary_pm_solo.table`, split by `Canary_topology.is_system_pm` | code |
| the mechanism buttons | `Canary_topology.artifact_variants`, from the mechanism catalogue | code |
| the cooperation buttons | `Canary_topology.coop_catalogue`, the kinds that have a band | code |
| the packages in canary | `band_instances` over the enumerated worlds of every catalogued project (`Canary_registry.all_specs`, so muted z3 is included) | code |
| what a mechanism hides | `Canary_topology.artifact_variant_of` (`av_hidden`) | code, as a rule |
| what a cooperation hides or greys | `Canary_topology.band_over` (`band_hidden`, `band_dead` over the chosen worlds) | code, as a rule. The rules return node ids without a reason, so a per-node source needs the rule to say which clause removed the node |
| the outlined package nodes | `Canary_overview_join.related` | code |
| "Canary runs this chain" | `jn_runs` | code |
| the notes beside the diagram | `av_note`, `co_package_join`, the `hand_cases` prose, `ps_package` | code, hand-written prose |
| the default choice | `default_choice` | code |

### 3.3 A recorded world: `overview_runs.js`, computed by `Canary_overview_runs.view_of_row`

A view exists for EVERY enumerated world of a package, whether it ran or
not: on the WSL machine, 39 views, one of them (an llvm world) with
nothing recorded. The "recorded world" selector therefore lists worlds,
not runs.

| what | from | believed source |
| --- | --- | --- |
| an edge's state | the steps `Canary_topology.place_step` puts on the edge, each in the state `actions.log` and its markers give, worst first | code × run: the placement is code and the state is run. The source to show is the log path and the step tags |
| `inside` | a placeholder step standing for an action edge that no step realized | code only. Placeholder steps are derived for every non-dummy fetch, whether or not it ran |
| `observed` | the bridge record's reading of the edges around the bridge | run |
| the badges | per realized edge, the agreements that apply to the chain's mechanism (`Canary_topology.edge_claims`); the filled badge's colour comes from the log's outcomes for exactly the checked ones | code × run |
| the candidate claims | claim sites the registry gives no evaluator that apply to the chain | code |
| the dimmed nodes | the nodes no live edge touches and no recorded name names | derived from the edge states and the names. An edge whose step was never logged (`unrecorded`) counts as live, so dimming does not tell a step that ran from one that never did |
| what is not drawn (`gone`) | `Canary_topology.world_gone` | code |
| the chain line | the record's chain (`topology_of_world`) | code |
| recorded on, span | the log's platform events and timestamps | run |
| the steps with no edge | `place_step`'s `Unplaced` reasons | code, over the realized steps |

### 3.4 Rules that live in the page's script

The page's stated rule is that the script decides nothing. In these five
places it does:

- `nearest()`: where no chain has the chosen combination, it lets go of
  the native side's package manager first, then the language side's;
- `pick('m')`: a mechanism with exactly one dependent package manager
  chooses it;
- a chosen package stays chosen only while all four choices agree with
  it;
- clicking a package manager off outlines nothing;
- `srcOf` repeats the route by which each value was looked up.

They are code, but code inside a JavaScript string, which the pins can
only search for text. Each can move into `Canary_overview_join` as data.
The fallback, for example, can become a precomputed nearest band per key.
It is then pinnable like the rest.

### 3.5 Outside §1

The agreement overview (§2: its decided and blame columns come from run
logs, the rest from the registry), the census (§3) and the catalogue
tables (§4) are not inventoried here.

## 4. How to trace the next workflow

This is the procedure §2 followed:

1. Start from the line of script that writes the value, and name the
   JSON field it reads.
2. Find the OCaml that fills that field. Follow each input to a
   declaration, a rule, a file under `_out`, or a process the renderer
   runs.
3. Make the function return the value with its source, from the same
   list. A second function that re-derives the source is the thing to
   avoid, because it can disagree with the value.
4. Carry the source in the data. Look it up in the script by the value's
   own route, and list it on the page.
5. Pin it: every shown value has a source; a run source names a file that
   exists; a render read is found by changing the machine's answer, not by
   restating the condition. Break each clause once before trusting it.

A suggested order: edge states first, since they are the core of a
recorded world, and each edge already knows its steps, whose log lines
are the source to cite. Then the badges, from the log's
`agreement_outcome` lines. Then the band rules, which need a reason per
hidden node. Then the script's five rules, moved into data. The render
read in §2 closes when phase E records `resolve_sys`.

# Proposal — resolving a placement to a concrete location

**Kind: proposal.** **Landed when** a placement resolves to its concrete
location through ONE function, no project computes an install prefix
itself, and "no two worlds write to the same place" is a derived check
rather than one project's pin. The map is [`README.md`](README.md).

> 2026-08-25, from the user's question after the stage-1 refactor: *"we
> can have an action to install an artifact with a given path, and there
> are following actions to consume that installed artifact. Where can the
> artifact carry the install path, so that an artifact itself can be
> aware of that?"* — followed by *"I have a feeling that we may have some
> abstraction which is not straightforward and have some duplication."*
> Both are right, and they are the same finding.

## 1. Why `Installed` carries no path (and should not)

The obvious answer to the question is `Installed of string`, by analogy
with `Vendored_at of string`. It is wrong, and the reason is a bug the
tree already has a pin for.

`Vendored_at` carries a literal because a vendored artifact sits at one
place **before any scenario exists** — a project fact. An install prefix
is not: z3's is `install-<ref>`, and the ref is a **placement
coordinate**. Two scenarios of one row must resolve to *different*
prefixes.

A literal in the declaration would therefore be one prefix shared across
worlds — which is exactly what let the fork's staged package answer the
pre-10549 world's staged probe and **silence a regression xfail**
(2026-08-19; `z3.install_prefix_isolated` exists because of it). And the
declaration cannot hold `assignment -> string` either: project
declarations are data-shaped and inspectable, which is the whole
`realize ∘ dispatch` split.

So the path does not belong to the declaration. It belongs to a step the
pipeline does not currently have.

## 2. What is actually missing

Nothing resolves a placement to a location. Concretely:

- **`Canary_store.location`** — `Build_tree | Staged | Pm of pm_info` —
  exists, is used ~80 times, and is **abstract**: it keys step tags
  (`probe_lib` / `probe_lib_staged` / `probe_lib_apt`, via
  `tag_of_probe_lib_location`) and their deps. It carries no path.
- **The path** is computed in per-project realization. z3 has
  `z3_paths ~source ~distro → (root, build, install_prefix)`, and its own
  comment records why it is one function: *"a second copy of this
  arithmetic is how the shared-install-prefix bug happened."* It was
  consolidated **after** the bug, not before.
- **A consumer** of a staged artifact gets the prefix by being handed it
  inside the same realization. Nothing outside can ask where an artifact
  ended up.

So an artifact cannot "be aware of" its install path because the pipeline
has no notion of a resolved placement at all.

## 3. The duplication — three types over one idea, and a lie in the gap

The second half of the question. There are **three** types describing
where/how an artifact exists:

| type | values | status |
| --- | --- | --- |
| `provision` | `Absent \| Fetched \| Built \| Installed \| Vendored` | live — the enumeration axis |
| `location` | `Build_tree \| Staged \| Pm of pm_info` | live — step tags and deps |
| `artifact_status` | `Built \| Installed_state \| Packed \| Fetched` | **DEAD — zero uses outside its own definition** |

`artifact_status`'s own comment admits it: *"Derivable from location for
now (Build_tree→Built, Staged→Installed, Pm→Packed or Fetched)."* It was
a third view of the same idea, and nothing ever read it. **Delete it.**

The remaining two are near-isomorphic:

```
Built     ↔ Build_tree
Installed ↔ Staged
Fetched   ↔ Pm
Vendored  ↔ ???
Absent    ↔ ———
```

**And the gap is a lie that is already costing something.** `location`
has no `Vendored` case, so a vendored world's probe is keyed
`Build_tree` (`canary_opam_binding.ml` — cairo, libffi, zlib, zstd all
probe a conda-forge prebuilt under a location that says "build tree").
Two consequences, both live:

- the matrix cannot tell a vendored probe from a built one — which is the
  same shape as the **location sub-axis** item already in the tracker,
  where an `Installed` world's `probe_lib_staged` renders as "not run"
  because the column only marks the step tagged exactly `probe_lib`;
- "which copy answered" has to be re-established at runtime by
  `Canary_world.Log_names` reading `/proc/self/maps`, because the static
  model cannot say it.

So: one dead type to delete, and two live ones that should be **one axis
with a projection**, not two hand-passed in parallel.

## 4. The shape

The same shape `ctx_of` already has for the workspace — one function, per
scenario, computed once and asked by everyone:

```ocaml
type resolved = { r_location : location; r_path : string }

val resolve : project_run -> assignment -> artifact_info -> resolved
```

The **kind** is derived from the provision — that is the isomorphism
above, made a function instead of a convention, with `Vendored` finally
getting its own case rather than borrowing `Build_tree`. Only the
**path** needs the project, and the row already knows most of it: a
staged artifact's prefix is a function of its `Built_from`'s build tree,
which is precisely what z3 computes by hand as
`build ^ "/../install-" ^ ref_id`.

## 5. What it buys

- **The prefix is looked up, not recomputed.** z3's bug class becomes
  structurally impossible rather than pinned.
- **`z3.install_prefix_isolated` generalizes.** "No two worlds resolve an
  artifact to the same write location", derived over the registry,
  replacing one project's hand-written pin. That is exactly the *general
  form* [`../staged_parity.md`](../staged_parity.md) §4 asks for and has
  never had — and it is stage 4's *partition a place* principle
  ([`stage4_order_worlds.md`](stage4_order_worlds.md) §2) applied where it was first
  needed.
- **The location sub-axis item resolves** (`../../project/status_project.md`):
  with a real `Vendored` location and a resolution per placement, the
  matrix can have a column per location instead of conflating them.
- **`emit --stage realize` can print it.** Today it shows the workspace
  but not where each artifact resolves — which is the thing you want when
  a staged probe reads the wrong copy.

## 6. Steps

1. **Delete `artifact_status`.** Zero uses; one type of the three gone
   for free. Independent of everything else.
2. **Give `location` a `Vendored` case** and stop vendored probes
   borrowing `Build_tree`. This changes step TAGS, so it moves scenario
   dir names and orphans warm markers — do it deliberately, expect a cold
   run, and check the tag pins first.
3. **`location_of_provision`** — make the isomorphism a function, and
   have `derive_steps` read it instead of taking the location as a
   parallel argument.
4. **`resolve`** in `Canary_pipeline`, beside `ctx_of`. Project-supplied
   path scheme; default a staged prefix from `Built_from`'s tree.
5. **Generalize the isolation pin** and retire `z3.install_prefix_isolated`.

Steps 1 and 2 are independently useful; 3–5 are the arc.

## 7. Risk worth stating

Step 2 renames step tags, and a scenario's dir name is its **cache key**.
The 2026-08-19 note on `scenario_dir_of` records what that costs: *"an
enumeration change silently RENAMED every scenario dir … every warm
marker orphaned, every project re-run cold, with nothing in the diff
pointing at it."* Here it would be deliberate rather than silent, but it
is the same cost, and z3 is a ~30-minute cold run. Sequence it when a
cold audit is wanted anyway — the C2 rename found five masked bugs
precisely because it forced one.

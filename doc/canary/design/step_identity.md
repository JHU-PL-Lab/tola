# Step identity — what names a check

**Kind: proposal.** **Landed when** a step's tag is a function of
(action × location kind) alone: `tag_of_probe_lib_location` is called
unconditionally in `derive_steps`, and no step tag anywhere contains a
package-manager name.

> 2026-08-26, user: *"are they two actions, that only used for sqlite?
> shall we at least have general actions so at least they are shared
> across projects? it also has a flavor that the project spec is not
> uniform at least for sqlite and other projects."* Measured before
> answering; the measurements are below, and two of the three worries
> turn out to be unfounded while the third is real and has a cost.

## 1. `probe_lib_apt` and `probe_lib_brew` are not actions

There is ONE action, `Probe_lib`. The realize JSON says so directly —
`{ "tag": "probe_lib_apt", "action": "probe_lib" }`. The tag comes from
`tag_of_probe_lib_location` (`action/canary_step_builder.ml:50`), which
lives in the action layer and is general machinery, not a sqlite
fixture:

```ocaml
| Build_tree          -> "probe_lib"
| Staged              -> "probe_lib_staged"
| Pm (Sys_pm { pm })  -> "probe_lib_" ^ string_of_pm pm
```

Nor are the two *declaration* styles a fork. sqlite authors typed
`action_row`s and Pattern-A projects fill a `runner_spec` field, but
`realize_from_rows` lowers a row into that same field
(`action/canary_action_templates.ml:390`), so both arrive as
`runner_spec.probe_lib : (location * cmd) list`. One model, one sugar
layer.

## 2. What IS non-uniform: the name depends on the neighbours

`derive_steps` (`canary_step_builder.ml:931`):

```ocaml
let ptag = if List.length spec.probe_lib = 1 then tag
           else tag_of_probe_lib_location loc in
```

A project with one lib probe gets the canonical `probe_lib`; a project
with several gets per-location tags. Measured across the roster:

| project | probe_lib tags |
| --- | --- |
| zlib · zstd · cairo · libffi · zarith · ssl | `probe_lib` |
| llvm | `probe_lib` |
| **sqlite** | `probe_lib`, `probe_lib_staged`, `probe_lib_apt` |

**zlib's `probe_lib` IS an apt probe** — its declared location is
`Pm (Sys_pm { pm = Apt })`, the same thing sqlite calls `probe_lib_apt`.
The identical check has two names, and which one it gets is decided by
how many siblings it happens to have.

Note what is *not* wrong here: sqlite having three lib probes is
sqlite being richer, not sqlite being irregular. It declares an
`Installed` provision, so it owes a staged probe; Pattern-A projects
provide their lib only `Fetched`, so one probe location is the correct
model for them. The count is modelling; the naming is the defect.

### Two consequences, both live

1. **Cross-project rows are not comparable.** `probe_lib` means "the
   only lib probe" in nine projects and "the build-tree probe" in
   sqlite. The result matrix puts those in one column.
2. **A spec edit silently renames a step.** Give any project a second
   probe location and its existing `probe_lib` becomes
   `probe_lib_<pm>`. Marker files are variant-keyed by tag, so the
   rename orphans every `.ok` marker and every matrix row that project
   has accumulated. Not a correctness risk — the cache key carries the
   switch and the platform, so a stale marker cannot be served across
   the rename — but a silent cold run and a broken history.

## 3. And the name embeds the platform

For a multi-entry project the tag carries the PM, and the PM is
*derived* from the platform (`system_pm_of_platform`). So the same check
is `probe_lib_apt` on Linux and `probe_lib_brew` on macOS.

[`platform.md` §8](platform.md) establishes that the enumeration is
platform-agnostic — both machines enumerate the same worlds. The
**record** is not: the two machines write different row names for the
same check, so their matrices cannot be laid side by side even though
the worlds behind them are identical. That is exactly the open question
in [`platform.md` §7 item 6](platform.md) — *how does a verdict name the
world it was earned in?* — arriving through the step tag rather than
through the output filename.

## 4. The principle

> **A step's identity is (action × location KIND). The concrete provider
> is data, not name.**

Location kind is already agnostic vocabulary: `Build_tree | Staged |
Pm (Sys_pm _) | Pm (Lang_pm _)`. Which PM realizes `Sys_pm` on a given
box is a platform fact, and platform facts belong to pass 5 and to the
record — `actions.log` already carries a `platform` event and an
`opam_switch` event per command, which is where "this apt probe ran
under apt" is properly said.

Proposed tags, unconditional and sibling-independent:

| location | tag |
| --- | --- |
| `Build_tree` | `probe_lib` |
| `Staged` | `probe_lib_staged` |
| `Pm (Sys_pm _)` | `probe_lib_syspkg` |
| `Pm (Lang_pm _)` | `probe_lib_langpkg` |

`tag_of_probe_location` (the binding probe) has the same shape and the
same fix; it is not exercised today because no project declares two
binding-probe locations, which is precisely why it should be corrected
before one does.

## 5. The cost, stated plainly

Renaming tags orphans existing markers and matrix rows for every
affected step: sqlite's three lib probes today, and any project that
later grows a second location. One cold sqlite run (~1 min) plus a
matrix whose sqlite history restarts. The switch/platform fingerprint
means this is cost, not risk.

That cost is why this is a proposal and not a commit: it is a rename
across the tracked record, and the record is the paper's evidence.

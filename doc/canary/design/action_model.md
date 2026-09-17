# The action model — what an action is, and what `_post` means

**Kind: rationale**, with one landed piece and one open design. Read it
before adding an action, before adding a step whose name ends in
`_inspect`, and before deciding where a check attaches. The procedure
for *adding* an action is [`action_playbook.md`](action_playbook.md);
this is the model the playbook realizes.

> Opened 2026-09-16 (user), from a question the codebase had answered
> four times in four places without ever stating: **what does
> `<action>_post` actually mean?** The answer turns out to be a
> distinction — a *moment* versus a *specification* — and the join that
> distinction needs did not exist. It does now; what it enables does
> not, yet.

## 1. An action is a moment with a typed footprint

An action is a node of the catalogue (`Canary_basic.store_actions`,
SSOT §6.5). It has:

- a **name** (`build_lib`, `probe_binding_ocaml`), which is also its
  step tag and its output directory;
- a **footprint** — `consumes_of_action` / `produces_of_action`, in
  coarse `artifact_kind`s;
- a **version rule** (`Ambient` | `Follows_input`) that says whether it
  inherits its inputs' version.

Everything else about it — the shell command, the checks around it, the
evidence it leaves — is *not* part of the action. It is per-project, or
derived, or both, and the confusions below are all cases of one of those
three being written down as though it were the action.

## 2. `<action>_post` is a HOOK, not a specification

`canary result`'s columns read `pre → action → artifact → post`. The
`_post` half is **a trigger moment: "the action has run, its outputs
exist"**. It is not a statement of what runs there.

That distinction is the whole item, and here is the test of it. A
**library inspection** — `nm -D` over the built object, recorded as a
summary — should be runnable at:

- `build_lib_post`, when canary built the library;
- `fetch_lib_post`, when a package manager delivered it;
- `install_lib_post`, when it was staged into a prefix;
- and a `fetch_package_post` for a package that happens to *contain* a
  library, which canary does not model yet.

It is the **same inspection** in all four. What differs is only **where
the file is**. So the inspection cannot be a property of `build_lib`; it
is a property of *the artifact* `lib`, invoked at whichever moment this
world actually produced it. **From the invoking side**, in the user's
phrase: the moment asks "what did I just produce, and what is there to
say about it?", rather than each action carrying a hand-placed list.

### What this rules out, and why

**`build_lib_inspect` as a standalone step is WRONG.** A check that
needs `nm -D` should just run `nm -D`. Adding a step whose only job is
to leave a file for a later step to read buys nothing and costs the
addressing problem: two names, two tags, two chances to disagree.

The evidence is not hypothetical. A stub inspection added through the
explicit `inspect` channel wrote correct evidence, that evidence was
read correctly, and **the step failed for a day** — because that channel
hardcodes every summary's base name to `inspect`, so a stub attached
through it lands at `inspect_stub_<vk>.json` and is judged against
`inspect_<vk>.json`. The evidence arrived; the address did not.

**`build_lib/` as a directory is NECESSARY.** Logs, markers and outputs
are per-moment and have to live somewhere per-moment. Nothing about the
hook model wants that removed.

**`build_lib_post` as a COLUMN is still needed.** The moment is
concrete: an action ran, and something is true afterwards that was not
true before. A column per moment is exactly right. What the column
*carries* is derived.

## 3. The join, landed 2026-09-16

A hook needs to answer "what did I just produce" in the project's own
vocabulary, and that answer did not exist. `consumes_of_action` speaks
in coarse KINDS (`Lib`, `Binding OCaml`); a project declares refined
IDENTITIES (`A_lib (Some "crypto")`, `A_binding (OCaml, Cstubs)`).
Nothing joined them.

The join is **pass 2** — it is spec-only and world-free, which is pass
2's membership rule ([`enumeration/stage2_analyse_spec.md`](enumeration/stage2_analyse_spec.md)):

```
an_touches : (action * { tc_consumes; tc_produces }) list
```

with three questions over it:

| function | question |
| --- | --- |
| `touches an action` | what does this action touch here? `None` = not in this project |
| `produced_at an action` | **the hook's question** — what did it just make? |
| `producers_of an artifact` | the hook's question backwards — where could this artifact's evidence come from? |

Print it:

```sh
canary emit sqlite --stage analyse      # the join is the first table
canary emit torch  --stage analyse --json
```

**Two lists and not one**, deliberately: a hook reads the produced side,
a precondition the consumed side. The flat `artifacts_of_action`
concatenates them, which is right for the diagram and wrong for a hook.

**It returns LISTS per kind**, not the first match.
`Canary_enumerate.find_artifact_of_kind` returns the first declared
artifact of a kind, which was fair while every project had one lib and
one binding per language. It is already wrong: tiny-full declares two
apps (`app-direct`, `app-via_helper`) and two Python bindings (`cext`,
`ctypes`), and `A_lib of string option` was landed in 2026-08-25 for the
second lib that is coming.

Pinned by `analysis.touches_joins_actions_to_declarations`, which
asserts three things: the join is **total** over a project's
declarations (a declared artifact no action reaches is unreachable); a
`Probe_*` **produces nothing** (`produces_of_action`'s claim restated in
the project's vocabulary); and a lib has **more than one** producer,
which is the fact the hook model stands on.

## 4. `probe_lib` is three roles wearing one name

Measured 2026-09-15, not inferred — read the commands:

| role | what it does | where it lives today |
| --- | --- | --- |
| **existence** | the artifact the world declares is there | `probe_lib`'s `test COUNT -gt 0` |
| **inspection** | record a projection as evidence | `probe_lib`'s appended summary; ALSO `build_lib`'s |
| **execution** | load it, run it, observe | **nowhere** |

`probe_lib` is static. Its command is `nm -D | grep -c <prefix>` then
`test COUNT -gt 0`: nothing loads and nothing executes. `probe_binding`
*is* runtime — it links a consumer, runs it, and greps the output for a
world witness — and it fuses all three roles in one `&&` chain.

Two consequences worth stating plainly:

- **Role 1 is a degenerate ancestor of a landed agreement.** "count > 0"
  is the weakest possible "exports what was declared", and
  `declared_symbols_exported` reads the NAMES. So role 2 is what the
  step is really for.
- **Nothing ever `dlopen`s a library.** A lib can pass every static
  check and fail to load — a missing transitive `NEEDED`, an
  unresolvable `RUNPATH`, a version-script mismatch the symbol table
  does not show. A role-3 `probe_lib` is NEW COVERAGE, not a
  reclassification, and it is the identity half `agreement/theory.md`
  §5.9 calls missing.

**The direction: `probe_lib` becomes an UMBRELLA.** The moment keeps its
name, its directory and its column; the concrete checks under it take
their names from the agreement registry, so a reader sees *which* check
failed rather than "the probe failed".

## 5. What a lib inspection actually varies in

Also measured, across the roster:

- all 13 `probe_lib*` steps run `nm -D` over the resolved file;
- all 11 `probe_binding_ocaml` + `probe_app_ocaml` steps compile and run
  an example;
- sqlite's `probe_binding_python` runs the interpreter;
- **llvm's `probe_lib` is the one outlier** — it runs `llvm-config
  --version`, which is *discovery*, not inspection.

And: `build_lib` and `probe_lib` inspect the SAME file and write
IDENTICAL content (sqlite: 270 symbols, same hash). Five such pairs
exist across the roster.

**So the only genuinely per-project part of a lib inspection is the
LOCATOR.** Everything after `LIB_NATIVE=…` is already shared. That is
the good news for the hook model and it is also where the next mess is:
**three locator vocabularies exist**, for one question.

| vocabulary | who uses it |
| --- | --- |
| typed `probe_lib_location` | sqlite, z3, llvm |
| `lib_locator` globs | the opam-binding template (cairo, libffi, zarith, zlib, zstd) |
| raw shell | llvm's `probe_lib` |

A hook that derives "inspect whatever this moment produced" has to
resolve a location, so **one locator vocabulary is a prerequisite**, not
a follow-up.

## 6. What is NOT done, in order

Tracked as [`../backlog.md`](../backlog.md) §52, which also carries the
older action-catalogue items.

1. **One locator vocabulary.** Three exist; the hook needs one. This is
   the blocking item and it is self-contained.
2. **Derive the inspection from the join.** Replace the hand-placed
   summaries with: at `<action>_post`, for each artifact in
   `produced_at`, run the inspection that artifact's kind defines,
   resolved at the location the world gives.
3. **Retire the world→tag maps.** `binding_evidence_tag` and
   `lib_evidence_tags` (in `agreement/canary_agreement_common.ml`) map a
   world to the step tag where evidence should be. `producers_of` plus
   the world's provision is the same function, derived instead of
   written — and it is the one the producer side would also use, which
   is what closes the placement class (backlog §50: *"the producer
   chooses a step, the consumer derives one, and nothing makes them
   agree"*, four instances, each fixed individually). This also settles
   the ownership question backlog §49 turns on: if the map is derived
   from the join, it stops living in the agreement layer at all.
4. **Split `probe_lib` into its three roles**, and add role 3 — the one
   nothing does.

**Do them in that order.** 2 without 1 hand-writes a locator per
project; 3 without 2 leaves two addressing schemes; 4 is independent
but is new coverage rather than a repair, so it is not urgent.

## 7. Where this sits

- The pass that owns the join —
  [`enumeration/stage2_analyse_spec.md`](enumeration/stage2_analyse_spec.md).
- The pass that realizes a step —
  [`enumeration/stage6_realize_steps.md`](enumeration/stage6_realize_steps.md).
- Adding an action, procedurally —
  [`action_playbook.md`](action_playbook.md): the ten touch points for a
  new action, the lighter checklist for a new artifact kind on an
  existing one, and what two worked examples taught.
- What a check CLAIMS, as against when it fires —
  [`agreement/README.md`](agreement/README.md).
- The evidence-workflow backlog this serves — `../backlog.md` §50.

# Where a check is evaluated

**Kind: proposal.** **Landed when** `canary_gh.ml` contains no verdict
logic — a check is an action the runner interprets and every backend
merely renders, so a step's judgement reads the same whether it runs
locally, on a GH runner, or under some future interpreter.

> Written 2026-08-30 for whoever picks up the agreement registry. It is
> the same conclusion as [`status.md`](../status.md)'s
> `[Pre; Action; Post]` entry (user, 2026-08-18, *"compiler
> perspective"*), reached from the opposite side: that entry came from
> enumeration coverage, this one from a CI backend that kept
> re-implementing verdicts and getting them wrong.

## 1. The finding: what a green CI badge currently means

`canary_gh.ml` renders `check_pre` and `check_post` **zero times.**

Locally a step can exit 0 and still be judged failed — that is exactly
how the sqlite pin bug surfaced (`check_post (FAIL)` after a command that
succeeded, because the switch did not hold the declared pin). On CI that
judgement does not exist.

> **A green CI job today means "every command exited 0". Nothing more.**

The sqlite pin bug would have been invisible there. So would any staged
lib that installs nothing, any fetch whose marker never appears, any
build that produces no artifact — every failure mode `check_post` was
written to catch.

## 2. Why the backend cannot express it

Locally, OCaml is the **interpreter**: canary runs, so a step's checks are
functions it calls. For CI, OCaml is the **compiler**: it emits YAML, and
the runner has ocaml but no *running canary* whose functions can be
called.

The step model makes that boundary concrete:

```ocaml
check_pre  : unit -> bool;
check_post : output_dir:string -> variant_key:string -> bool;
```

**Closures.** A closure cannot cross the compiler/interpreter boundary, so
the backend has two options and takes both badly: inline a decision it
computed itself (which is what the expectation rendering does), or omit
the check entirely (which is what happens to `check_pre`/`check_post`).

The defect stated once: **the compiler emits decisions where it should
emit calls to a decision procedure.**

### What that cost, measured

Three bugs in one day, all of them the emitted shell disagreeing with the
runner it was supposed to mirror — a derived expectation rendered with the
oracle's polarity, an unresolved prediction read as "artifact is good",
and a verify grepping a log filename the step does not write. Each was
fixed in the shell copy. None of them could have existed if there were one
copy.

## 3. The two halves have very different costs

This is the part worth knowing before scoping the work.

**`check_post` is nearly free**, because it is already shell-shaped:

| compositor | what it is | as shell |
| --- | --- | --- |
| `has_file` | `Sys.file_exists` | `test -f <path>` |
| `check_markers` | conjunction of `has_file` | `test -f a && test -f b` |
| `check_build_lib` | marker + lib exists | `test -f` + a glob test |
| `pin_check_post` | marker + `holds_pin_cmd` | **already a shell string** |
| `default_check_post` | one marker | `test -f` |

**Expectation evaluation is not.** `predicted_contains_any_v2` parses the
`inspect.json` a run produced and drives the c1..c8 comparators. That is
real OCaml over real data, and it is why the current backend resolves
predictions at GENERATION time from the laptop's cache — which is also why
an xfail on CI is checked by signature when that cache exists (ssl) and by
polarity alone when it does not (llvm).

Conflating the halves makes the work look bigger than it is. The cheap
half can land first.

## 4. The constraint on whoever implements it

**One constructor must yield both forms.** The tempting shortcut is to add
a `check_post_sh : string` beside the existing closure and hand-write the
shell. That is a second representation of one decision — the precise
disease that produced §2's three bugs, and the same shape as the
`*_ci_spec` values that silently dropped sqlite's binding half. If a check
has a predicate and a rendering, they must come out of the same
constructor, or the check must simply BE a command that the runner
interprets like any other.

The second is `[Pre; Action; Post]`, and it is why building the dual first
is worse than waiting: the redesign deletes it.

**Keep the check vocabulary small and declarative** — file present, marker
present, pin held, output contains, symbols exported. The failure mode is
it growing into an expression language, at which point a shell has been
rebuilt inside OCaml types.

**Note that some closures are already shell-outs pretending to be
predicates.** `pin_check_post` goes through `Canary_store.sh_in_switch`.
As actions those become *more* honest, not less.

## 5. Why the agreement registry is the natural home

[`agreement_registry.md`](agreement_registry.md) is the catalogue this
section means.

A contract is a check with declared inputs and an expected outcome, so
"registry → check actions" is a projection rather than a translation. That
gives one place where the belief matrix is defined, and
[`status.md`](../status.md)'s entry already names the payoff: every cell
becomes an action in the graph and the coverage pin becomes an enumeration
invariant.

**The IR question to settle first**, because it decides how much any
future backend must know: does a check action carry its *implementation*
(a command) or its *meaning* (a contract id + inputs, resolved to a command
by someone)? The first makes a Python or Rust interpreter trivial and the
registry a compiler; the second keeps the meaning legible in the step list
and pushes resolution into every backend.

## 6. The payoff beyond CI

If checks are data, GH Actions stops being special. The step list carries
its own judgements, so any interpreter of it — the local runner, a GH job,
a Python or Rust runner, another CI — reaches the same verdict by
construction. The current YAML backend is not a rendering of the pipeline
so much as a partial reimplementation of it, and that is the thing to
retire.

## Reading CI output in the meantime

- A `continue-on-error` step shows an **orange icon and
  `Error: Process completed with exit code 1`** in the GH UI. For an
  expected failure that is correct — the paired `(verify)` step is the
  verdict. llvm's `probe_binding_ocaml` and ssl's `probe_app_ocaml` both
  look alarming and are green.
- Do not read a green job as "canary agrees" — see §1.

# Issue — dune startup scans the run-output dirs (3.5s overhead per command)

**Status**: fixed 2026-08-13 — in the WORKING TREE only (uncommitted on
`ds-workflow`, like all post-2026-08-06 work). A fresh checkout from HEAD
(`75b067e`) has neither fix; see §5.
**Found**: 2026-08-13, user report: "any canary command takes time to scan
the project directory, which is not the same as before"
**Fix**: root `dune` `(dirs ...)` exclusion + filtered docs copy in
`canary_diagram.ml` + one-time prune. All verified.

---

## 1. The symptom

Every `dune` command — even `dune exec src/bin/canary_main.exe -- paths` —
took ~3.5–4s before producing output. The canary binary itself was fast
(0.25s); the cost was entirely dune's startup, and it grew over recent
weeks as run output accumulated.

## 2. Root cause

Dune walks the project tree on every invocation. Two directories had
ballooned inside the project root:

| dir | size | files / dirs | why dune walked it |
| --- | ---: | ---: | --- |
| `docs/` | 27G | 520k / 48.5k | normal dir inside the dune project root; `data_only_dirs` does not prune the walk |
| `_out/` | 18G | 459k / 67k | data-only dirs stay in dune's file tree, and the `(dirs ...)` exclusion does not apply to them |

Measured decomposition (all times `dune describe workspace`):
clean HEAD worktree 0.08s → +docs 1.7s → +_out 1.2s → 3.1s total.

The bloat's source: `canary_diagram.ml` (old L2349) did
`cp -r <run_dir>/* docs/canary/projects/<project>/` — a blanket copy of
whole run directories (fetched source checkouts **including `.git`**, build
trees, install trees) into the git-tracked docs tree on every run. Only
~379 files in `docs/canary` were tracked; everything else was churn
(`docs/canary/projects/llvm` alone reached 22G). The three post-hoc
`find -delete` prunes (`.ok`, `pack-repo`, `*_example*`) were patches on the
same over-broad copy.

## 3. The fixes

**3a. Root `dune`** — exclude the output dirs from dune's directory set:

```lisp
(dirs :standard \ {docs,_out})
(data_only_dirs reference vendor _pm _cache _legacy_code _opam _not_used _not_yet _harness _build)
```

`(dirs ...)` prunes the walk, but only for non-data-only dirs — so `_out`
had to come *out* of the old `_*` data-only pattern to be excludable. The
`_*` pattern was replaced by an explicit enumeration of everything it was
protecting (verified against HEAD: identical `describe workspace` modulo
new modules; identical tiny-project behavior).

**3b. `canary_diagram.ml`** — `write_project_output`'s docs copy is now a
filtered recursive copy in OCaml (no shell), replacing the `cp -r` and the
three post-hoc prunes:

- extension whitelist: `.json` / `.log` / `.mmd` / `.html` (covers 100% of
  the tracked web set)
- artifact-dir blocklist (never descend): `.git`, `_build`, `_cache`,
  `_opam`, `pack-repo`, `src`, `build`, `install`, `lib`, `bin`, `staged`,
  `sandbox`, `workspace` — needed beyond size alone: source checkouts
  contain thousands of junk `.json` files the ext filter alone would copy
- `*_example*` files skipped at copy time

**3c. One-time prune** — `docs/` 27G → 53M (501k → 3.2k files); untracked
churn 868 → ~120. The 4 accidentally-tracked ssl probe binaries
(`ssl_app_core`/`ssl_app_nlv` in `ssl` + `ssl-variant`) deleted and
gitignored (`docs/**/ssl_app_*`); they show as `D` pending commit.

## 4. Verification (2026-08-13)

- `dune describe workspace`: 3.1s → **0.08s** (measured with the 27G/18G
  still in place — the dune fix is structural, not cleanup-dependent)
- `dune build` (idempotent): 3.5s → **0.33s**
- `dune exec ... -- spec-check @all`: ~4s → **0.49s**
- `canary view llvm` end-to-end: web files refresh (result.html, diagrams,
  per-scenario probe logs, install-diff JSONs), zero junk added
- `make canary-test`: 60/60 + 107/107 + 14/14

## 5. ⚠️ Worktree preparation

**Nothing here is committed.** HEAD is `75b067e` (2026-08-06); `ds-workflow`
carries ~2 weeks of uncommitted work, and these fixes are part of it. A
fresh worktree from HEAD has the old root `dune` and the old blanket
`cp -r`. A fresh checkout is fast initially (no junk), but the first
llvm/z3 runs will grow `_out`, and at HEAD-config dune walks it (~1.2s and
climbing). Either commit first, or replicate the root `dune` change in the
new worktree.

## 6. Follow-ups (filed in `doc/canary/backlog.md`)

- **`CANARY_OUT` env var** — global cache-path feature (user, 2026-08-13):
  `_out` is the literal string at ~10 bin-layer call sites, all flowing
  through `~root` params, so it's a one-helper refactor. `_out` carries
  real build caches the user wants to preserve. If it lands, any in-repo
  output dir needs an entry in the `(dirs ...)` exclusion.
- **Diagram regeneration** (user: planned later): the filtered copy lives
  in `write_project_output`'s tail, so any diagram redo inherits it.
- The other `_cache` (tiny-factory's scenario workspace cache,
  `canary/examples/tiny/scenarios/_cache/`, 169M, gitignored) is explicitly
  data-only-protected in the new root `dune` — not relocatable yet, lower
  priority.

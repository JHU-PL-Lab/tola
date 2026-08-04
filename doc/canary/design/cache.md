# Run cache — how canary skips already-done steps

> Short note (2026-08-03) triggered by the provision-variety work: does the
> cache support **multiple build results** for one artifact (Vendored vs Built,
> dev vs stable)? **Yes** — the discriminator is `variant_id`. This documents
> the two layers so we don't confuse a *stale cache hit* for a *real run*.

## Two layers (`backend/canary_local_runner.ml`)

1. **Global cache** — `load_cache ~path` reads a committed
   `step_cache.json` (CI global skip). Key = **`"<project>:<step_tag>"`**
   (`cache_is_success tbl ~key:step.cache_key`). Off unless `~cache_path` is
   given (`run_step … ?global_cache`).
2. **Local cache** — no file needed: a step is skipped when its output dir
   exists **and** `check_post` passes (the step's `.ok` **marker** is present).
   This is the idempotent "already produced" skip — the one that masked the
   Built build in the demo.

Skip priority in `run_step`: (1) global cache hit, then (2) local postcondition
already passes.

## The discriminator is `variant_id`

`project` is `"<name>/<variant_id>"` (e.g. `"tiny/app_over_binding_ocaml"`).
`output_dir_for` splits it: the **directory** is keyed only by the name
(`_out/canary/projects/tiny/<step_dir>/`), but the **marker/artifact filename**
carries the variant — `Canary_basic.variant_file ~variant_key:step.variant_id`
→ `build_lib/build_app_over_binding_ocaml.ok`. The global `cache_key` also
embeds it (via the full `project`). So:

> **Different `variant_id` ⇒ different marker file + different cache_key ⇒ the
> results coexist.** One project dir holds many variants side by side.

## Implication for provision / version variety

The cache is **not** the obstacle. To run a **Built** and a **Vendored** build
of the same artifact (or **dev** vs **stable**) without collision, give them
**distinct `variant_id`s** — encode the discriminating axes, e.g.
`app_over_binding_ocaml@built@dev` vs `…@vendored@dev`. Then each caches
independently; re-running one never serves the other's marker.

What went wrong in the `tiny built-check` demo: it reused
`variant_id = app_over_binding_ocaml` for a **source-only** (Built) workspace,
so the local marker from the earlier **Vendored** run made `build_lib` skip —
a stale hit, not a real build. `rm -rf _out/canary/projects/tiny` cleared the
markers and the real `cc` build ran. **Fix when wiring Built into the
enumeration: put provision (+ version) in `variant_id`.** No cache change
needed.

## Soundness: the skip must key on a MET expectation, not output presence (bug B, 2026-08-03)

The local-cache short-circuit and the `run_graph` seed originally skipped a step
when `check_post` passed. For a **probe**, `check_post` is only "`probe.log`
exists" — and a probe writes `probe.log` *even when it fails* (`> probe.log
2>&1`). So a **failed** probe was served as a cached success on the next run:
the step was skipped and reported `done`. Effect: warm reruns painted
**every** bad scenario green (`tiny-full` read a fake `24/24`; the honest cold
number was `3/24`), silently inflating the detection metric.

**Fix:** the runner writes a per-step **verdict marker**
(`<tag>.verdict_<variant>.ok` in the step's output dir) *only when the step met
its expectation* (`Canary_local_runner.write_verdict`, gated on
`expectation_ok && symbol_ok`). Both skip sites — the `run_step` local cache and
the `run_graph` `Step_done` seed — now key on **that marker**, not on
`check_post`. A failed probe leaves no marker, so it re-runs; a genuine success
caches (cold `316` → warm `35` command events on `tiny-full`). Old caches carry
no marker, so the first run after this change re-runs once (self-healing).

Guarded by `canary cache-test` (`test/canary_cache_test.ml`): asserts a failed
step re-runs (probe.log present, ran twice, no marker) while a success caches
(ran once, marker present). Reverting the skip condition to `check_post` fails
the first case — a real regression guard, per the two-testing-axes philosophy.

## Forcing a fresh run

- clear the local markers: `rm -rf _out/canary/projects/<name>` (or the step's
  output dir), or
- use a distinct `variant_id` (the normal path — a different variant *is* a
  different run).

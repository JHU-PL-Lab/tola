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

## Forcing a fresh run

- clear the local markers: `rm -rf _out/canary/projects/<name>` (or the step's
  output dir), or
- use a distinct `variant_id` (the normal path — a different variant *is* a
  different run).

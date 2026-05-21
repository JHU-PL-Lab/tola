---
name: Never delete contrib/ build caches
description: When cleaning _out/canary or similar, never touch contrib/* — the build caches there are heavy (z3, llvm source builds take hours)
type: feedback
---

When cleaning up generated output (e.g. `_out/canary/projects/*`,
`_out/canary/test/*`), the user has explicitly said it's safe to wipe those.

**Never** delete or `rm -rf` anything under `contrib/` or `~/code/contrib/`
or any project's build cache directories that take significant time to
rebuild. Specifically: z3 source builds (~30 min cold), llvm source builds
(hours), and other Pattern C self-build artifacts.

**Why:** User explicitly asked to never delete contrib's building cache
because it's heavy. A wrong `rm -rf` here costs hours of rebuild time.

**How to apply:** When proposing or executing cleanup commands, only target
`_out/canary/` (which is gitignored output) and similar regenerable dirs.
For anything under `contrib/`, ask first or skip entirely.

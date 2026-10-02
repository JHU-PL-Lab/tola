---
name: feedback-protect-contrib-cache
description: Never delete anything under contrib/ — the z3 and llvm builds there take hours to redo
metadata:
  type: feedback
---

Generated output under `_out/canary/` is safe to wipe. Never delete
anything under `contrib/` (`~/code/contrib/`) or another build cache that
is slow to rebuild: a cold z3 source build takes about 30 minutes,
llvm's hours.

**Why:** the user asked explicitly; a wrong `rm -rf` there costs hours.

**How to apply:** cleanup targets `_out/canary/` and similar regenerable
directories only; anything under `contrib/` is asked about first or left
alone.

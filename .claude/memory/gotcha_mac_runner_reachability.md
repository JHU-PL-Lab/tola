---
name: gotcha-mac-runner-reachability
description: Reaching and syncing the macOS box — its IP moves (find it with ARP), mDNS is unreliable, push from the host
metadata:
  type: project
---

The mac (`AngryRedPanda`, macOS 15, arm64, user `ex`) is canary's second
machine.

- **Its address moves, and that is accepted** (user's call). When
  `ssh mac` fails, suspect the DHCP lease first. From WSL a dead address
  shows as `No route to host` in a ping reply from the Windows host,
  which looks like a firewall and is not one. Find the mac with
  `/mnt/c/Windows/System32/ARP.EXE -a` (a locally administered MAC,
  `a2:…`), probe port 22, and update `Host mac` in `~/.ssh/config`.
- **Not mDNS.** `AngryRedPanda.local` resolves but connects only about
  half the time (a link-local `fe80::` comes first); use the IPv4
  address.
- **Sync by pushing from the host:** `git push mac:code/research/tola
  main:refs/heads/main`. The mac cannot reach WSL, so it cannot pull.
- **Keep it synced.** A stale mac once hid a macOS test failure for 18
  days. Running canary there needs a current checkout; a thin remote
  runner would need only `canary/scripts/` and a working directory.
- The mac runs canary in its ambient opam switch (OCaml 5.4.0), WSL in
  the `canary` switch (5.4.1); the platform is part of the step
  fingerprint, so their verdicts never mix.

Related: [[gotcha-shared-working-tree]].

---
name: gotcha-mac-runner-reachability
description: Reaching and syncing the macOS box — DHCP moves its IP (tolerate and update), mDNS connects only ~50%, and leaving it unsynced hid a macOS test regression for 18 days
metadata:
  type: project
---

The mac (`AngryRedPanda`, macOS 15.7.3, arm64, user `ex`) is the second
canary machine and the prospective runner for the remote-runner work
(`doc/canary/status.md` §2.1).

**Its address moves, and that is accepted.** `~/.ssh/config` had `Host
mac` at `10.0.0.203`; the router had re-leased it to `10.0.0.116`
(2026-09-21). Port 22 was never the problem — sshd is up and key auth
works with `BatchMode=yes`. User's call: tolerate the churn and update
the IPv4 address when it changes, rather than chase a static-lease
setup. So when `ssh mac` fails, **suspect the lease first**. WSL is
NAT'd behind the Windows host (`10.0.0.192`), so a dead LAN address
surfaces as `No route to host` *in a ping reply from the Windows host*,
which reads like a firewall block and is not one. Re-find it with
`/mnt/c/Windows/System32/ARP.EXE -a` — the mac appears with a
locally-administered MAC (`a2:…`, Apple's private Wi-Fi address) — then
probe port 22 and update `~/.ssh/config`.

**Do not "fix" it with mDNS.** `AngryRedPanda.local` *resolves* from WSL
and looks like the durable answer. It is not: measured 8/8 connects on
the raw IP against **~50% on the name**, because the resolver returns a
link-local `fe80::` first and `-4` does not rescue it. This matters
beyond convenience — a transport that silently fails half the time is
the "a remote command that did not run must not look like a check that
passed" failure mode.

**The mac needed a RESET, not a pull** (done 2026-09-21). It sat on
`ds-workflow` at `d74163f` (2026-08-26), which is *not* an ancestor of
the live line — `ds-workflow` was rebased and force-pushed past it, so
the two diverged at `75b067e5`. Content-wise nothing was lost (189 of
190 commit subjects duplicated; the one that was not had landed anyway).
Transport that avoids GitHub entirely: `git push mac:code/research/tola
main:refs/heads/main` from the host — the host can reach the mac, but
the mac cannot reach NAT'd WSL, so the push must go this direction. Its
pre-reset HEAD is kept on the mac as branch `mac-standalone-2026-08-26`.

**What the mac actually needs on disk — less than a checkout.** Step
commands address the inspectors by RELATIVE path (`"canary/scripts/
inspect_native.py"` in `canary_artifact_native.ml`, no repo-root
prefix), so a thin runner needs the `canary/scripts/` payload and a cwd,
not the OCaml source or a dune build. Measured: all 8 shared inspector
scripts were byte-identical host↔mac after three weeks of drift. Only
the *cheap path* (mac runs its own canary and publishes `actions.log`)
needs a full current checkout.

⚠ **But staleness is not free, and here is the proof.** Updating the mac
turned `make canary-test` from 113/113 to **112/113**:
`native.summary_json_schema` fails with *"symbols empty — --emit-symbols
lost?"*. Cause: the macOS test fixture passes `--prefixes "_"`
([`canary_artifact_test.ml`](../../src/canary/test/canary_artifact_test.ml)
`native_shell_tests`) while `inspect_cmd` adds
`--strip-leading-underscore` on macOS, so symbols are stripped to
`sqlite3_*` and then filtered by prefix `_` → empty. `counts.total` is
not prefix-filtered, so it stays > 0 and only the symbols assert
catches it. The `"_"` fixture landed 2026-08-26 (green then); the
`assert len(d['symbols']) > 0` landed **2026-09-03**, eight days after
the mac last synced — and went unseen for 18 days. Note
`native.probe_cmd` still PASSES with that prefix because it greps raw
`nm` output where `_` matches nearly everything: a vacuous pass sitting
right beside the honest failure.

The mac has no dedicated `canary` opam switch and is not supposed to —
`Canary_store.default_switch_of` maps `MacOS_local -> None` (ambient),
`Wsl -> Some "canary"`. Ambient there is OCaml 5.4.0 against WSL's
5.4.1, the untracked-toolchain gap in `design/artifact_cache.md`
§4.6–4.7; today the platform rides the step fingerprint so the two never
share a verdict.

Related: [[gotcha-shared-working-tree]], [[project-canary-ci]].

---
name: gotcha-mac-runner-reachability
description: Reaching the macOS box from WSL — its LAN IP is DHCP-churned, mDNS from WSL connects only ~50%, and its checkout was orphaned by a ds-workflow force-push
metadata:
  type: project
---

The mac (`AngryRedPanda`, macOS 15.7.3, arm64, user `ex`) is the second
canary machine and the prospective runner for the remote-runner work
(`doc/canary/status.md` §2.1). Three facts about reaching it, all found
the hard way on 2026-09-21.

**Its address moves.** `~/.ssh/config` had `Host mac` at `10.0.0.203`;
the router had re-leased it to `10.0.0.116`. Port 22 was never the
problem — sshd is up and key auth works with `BatchMode=yes`. When `ssh
mac` fails, suspect the lease before anything else: WSL is NAT'd behind
the Windows host (`10.0.0.192`), so a dead LAN address shows up as
`No route to host` from a *ping reply sent by the Windows host*, which
reads like a firewall problem and is not one. Find it again with
`/mnt/c/Windows/System32/ARP.EXE -a` — the mac appears with a
locally-administered MAC (`a2:…`, Apple's private Wi-Fi address) — then
probe port 22. **The real fix is a DHCP reservation on the router**;
until that exists this will drift again.

**Do not "fix" it with mDNS.** `AngryRedPanda.local` *resolves* from WSL
and looks like the durable answer. It is not: measured 8/8 successful
connects on the raw IP against ~50% on the name, because the resolver
returns a link-local `fe80::` first and `-4` does not rescue it. This
matters beyond convenience — the remote-runner prompt warns that *a
remote command that does not run must not look like a check that
passed*, and a transport that silently fails half the time is exactly
that failure mode. Keep the IP in `~/.ssh/config`.

**Its checkout is orphaned, not merely stale.** The mac sits on
`ds-workflow` at `d74163f` (2026-08-26, the mac → WSL handoff commit).
That is *not* an ancestor of the current line: `ds-workflow` was
rebased and force-pushed past it, so the two diverge at `75b067e5`.
Content-wise nothing is lost — 189 of its 190 commit subjects are
duplicated on the live line, and the one that is not (`d770aa46`,
the worktree section of CLAUDE.md) landed anyway. So the mac needs a
**reset, not a pull**; `git pull` there will fail or make a merge
commit. Its two stashes are dead (they touch
`src/bin/canary_project_z3.ml` and `doc/opam.md`, paths that no longer
exist).

The mac has no dedicated `canary` opam switch and is not supposed to —
`Canary_store.default_switch_of` maps `MacOS_local -> None` (run
ambient) and `Wsl -> Some "canary"`. Its ambient switch is 5.4.0 against
WSL's 5.4.1, which is the untracked-toolchain gap in
`design/artifact_cache.md` §4.6–4.7; today the platform rides the step
fingerprint so the two never share a verdict.

Related: [[project-canary-ci]].

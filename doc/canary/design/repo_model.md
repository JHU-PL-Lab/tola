# The repo model — requirements for the 3-way repos in the project spec

> 2026-08-14, user. Design input for the 3-way task (stable / official-latest
> / forked repos per project) and the repo-provider unification. Requirements
> from the user; DECIDED points marked. Not yet implemented.

## Requirements (user, 2026-08-14)

1. **Git repos are DISTRIBUTED by default.** A repo representation models
   the LOCAL and the REMOTE separately, and they may differ: the official
   repo gets a local fork; our forked repo has its own remote (github
   primary, other hosts supported) and a working local checkout.
2. **WORKTREES for per-version checkouts** (DECIDED 2026-08-15, user):
   one repository (shared objects) + a `git worktree` per tracked
   version/ref — better than separate clones (no duplicated object
   stores, still no in-place `git checkout <ref>` churn). Several
   versions coexist per project (a tracked stable and a tracked latest,
   both of which can UPDATE) — so **stable/latest are DESCRIPTIVE
   markers, not fixed identities**.
3. **Refresh is ON-DEMAND** (DECIDED): given computing resources, there
   is no value in automatically catching up every nightly build (even
   with a GH cron) — versions refresh when a run/prepare asks for them.
4. **The contrib layout is a CONFIG, not hardcoded** (DECIDED):
   `~/code/contrib/<project>-all/<repo-variant>` is the convention. No
   config files IN contrib (other projects decide on their own after
   reading its README) — for canary it is **data in code, a base-layer
   setting** (an alternative home is the run config's policy field).
   Directory naming respects the repo's OFFICIAL name, with a naming
   scheme fallback when the repo has no name. **A README lives in
   `~/code/contrib/`** — other agents/projects work in those trees too.

## Current shape and its gaps

```ocaml
(* tool/canary_artifact_source.ml *)
type git_remote = Git_remote of string          (* ONE remote, host-agnostic *)
type local_path = { distro; path; build_path }  (* distro-keyed, HARDCODED *)
type source_repo = {
  name : string;  remote : git_remote;  locals : local_path list;
  version; ref_; official : bool;  build_sys_deps;  api_source;
}
```

| requirement | today | gap |
| --- | --- | --- |
| local ≠ remote (fork vs upstream) | `remote` + `locals` exist | NO fork relation: `official : bool` is a bare flag; no `upstream` field |
| per-version worktrees, descriptive markers | one checkout per repo; `git checkout <ref>` in place | no worktree model; version identity vs "stable/latest" marker conflated |
| on-demand refresh | fetch happens per scenario (guarded by markers) | ✓ roughly, but tied to scenario runs, not a standalone refresh |
| contrib layout as config | `Canary_store.distro_base` hardcodes `/home/red/code`; projects hardcode relative paths (`mk_locals`) | two hardcoded layers; no naming scheme; no README |
| remote host generality | `Git_remote of string` — any URL | ✓ (spec-check's public-forge rule reads the string) |

## Sketch (DECIDED points folded in — not implemented)

```ocaml
type remote = { url : string; host : string }        (* "github.com" | "gitlab.*" | ... *)

(* The fork is a VARIANT on the repo, not a channel (DECIDED
   2026-08-15). The property/enumeration split (user, the core of Q1):

   - REPO PROPERTIES: [ref_] (commit/tag), [official], the stable/latest
     markers (descriptive — they POINT at refs and can update), and a
     FREE LABEL for identity (e.g. [Fork "arbipher"]).
   - ENUMERATION: WHICH repos a scenario set runs against — stable-only
     (confirm the command spec is correct), stable+dev (the correctness
     matrix), all three (the report) — belongs to the ALGORITHM and
     CONFIG, i.e. the run_policy ladder, NOT to the repo properties. *)
type repo_variant = Stable | Latest | Fork of string   (* draft: the free label *)

type repo = {
  name : string;                 (* the OFFICIAL repo name — drives contrib dir naming *)
  remote : remote;               (* where WE fetch/push: our fork, or the official when unforked *)
  upstream : remote option;      (* the official upstream when [remote] is our fork (distributed) *)
  official : bool;               (* DECIDED: fine as a repo field (a project_spec field also ok) *)
  worktrees : (repo_variant * string (*ref_*) * string (*path*)) list;
                                 (* per-version WORKTREES (DECIDED 2026-08-15:
                                    one repo + git worktree per ref, shared
                                    objects); paths derived from the contrib
                                    setting + name *)
  (* … version/ref/build_sys_deps/api_source as today, restated per repo *)
}
```

- A **per-channel provider** becomes `Repo of (channel * repo) list`
  (or repo-variants) — the 3-way's data shape.
- **Lifecycle** (DECIDED): the project's current style — a
  prepare/realize pass creates/refreshes the per-version clones
  on-demand. In the FUTURE prepare/fetch becomes a normal dynamically
  dispatched action; NOT for now.
- The Fetched-source-id run-cache-key item (status_project.md §3) may
  get redefined by the variant field — discuss when the 3-way lands.

## Settled since (2026-08-15)

- **The OFFICIAL shape** (user): a remote repo + a LOCAL repo (the
  clone); when the official is a git repo, several WORKTREES cover the
  separate tags/versions.
- **OUR FORK** is usually ANOTHER repo (a distinct repo, not a worktree
  of the official), and our fixing usually lives only in the DEV
  variant (the fork tracks/fixes dev — a stable fix is rare and
  upstream's business).
- **The fix targets are dev BUGS *and* dev MISMATCHES** (user): any dev
  — lib dev or binding dev — becomes the next stable when released, and
  two devs may work against EACH OTHER (dev-lib × dev-binding cross
  mismatch). The checking pipeline: find the error/mismatch → identify
  the BLAMING part → have the fix.

## The multi-repo principle (user, 2026-08-15)

The z3 mental model (one repo with lib + all bindings) does NOT
generalize — many projects have a SEPARATE repo per artifact.

- Any BUILT artifact can have a repo carrying the source to build it;
  if the artifact has stable/dev, its source does too.
- Both artifacts can share one repo. The MODELING direction is
  REVERSED: a repo records WHAT ARTIFACTS it can contain
  (repo → artifacts), not artifact → repo. Matches the ON-TREE
  vocabulary: a main project's source tree may hold the lib + the
  official binding(s) (on-tree), while an unofficial binding is
  OFF-tree (its own repo).

Sketch: `source_repo` gains `artifacts : artifact_id list` (e.g.
Z3Prover/z3 = [lib; binding OCaml; binding Python]; ocaml/Zarith =
[binding OCaml]; GMP's repo = [lib]). Artifact rows' `Repo r` providers
then reference repos whose contents include them — a consistency
invariant the checker can pin (an artifact must appear in its provider
repo's contents).

- This GENERALIZES the ad-hoc per-source booleans the old spec carried
  (`has_build_lib`/`has_build_binding` — still visible in z3's legacy
  [lib_cmd_of_source]/[binding_dir_cmd_of_source] helpers, consumed by
  the pre-A5 CI path): "this source can build the binding" is just the
  contents list.
- ON-TREE vs OFF-TREE is DERIVED, not declared (user: "our data type
  has already captured it"): the artifact↔repo relation IS the
  per-artifact [Repo] provider; on-tree-ness = the artifact's repo is
  shared with the project's other artifacts (readable off the contents
  lists). No new "main repo" field.
- An INACCESSIBLE source does not break checking (user): the
  enumeration and artifact checking still detect a wrong scenario and
  blame it — the source repo is optional provenance. GMP's repo is
  actually OPEN (gmplib.org/repo/gmp — hgweb, HTTP 200) but is hg +
  tarballs, outside the git model; gmp dev stays unmodeled for now.



- **The OFFICIAL shape** (user): a remote repo + a LOCAL repo (the
  clone); when the official is a git repo, several WORKTREES cover the
  separate tags/versions.
- **OUR FORK** is usually ANOTHER repo (a distinct repo, not a worktree
  of the official), and our fixing usually lives only in the DEV
  variant (the fork tracks/fixes dev — a stable fix is rare and
  upstream's business).

- **The fork needs NO remote** (user): a LOCAL-ONLY fork is fine — it is
  a WARNING, not an error (we check a series of projects and may not
  find a bug worth pushing; a per-project remote on the personal github
  account is not required). What is REQUIRED is the local fork itself.
  Implemented: `source_repo.remote : git_remote option` (None = local
  only — the worktree cmd requires the checkout to pre-exist, loudly);
  spec-check's public-remote gives a Warn for a labeled repo without a
  remote. Pin: `spec_check.local_fork_warns`.
- **Official repos without any git** (archive files / PM-handled
  source) — recognized as a real case, DEFERRED: all current projects
  have remotes.

## Open decisions left for the 3-way design

1. **The variant vocabulary** — what names/carriers distinguish the
   three repos (stable / latest / fork) in the enumeration and the
   scenario identity; the fork's label (repo name? owner?).
2. **Config carrier** — base-layer setting (data in code) vs run-config
   policy field — the user allows either; pick at implementation.
3. **Naming scheme fallback** — when a repo has no official name:
   slugify what (remote URL's last segment? project name + variant)?

## Roadmap — the repo-model upgrade (2026-08-16, user-approved shape)

The user: "upgrade the whole project and retire the old code. we can do
it after or before the one or more 3-way landing or more checking
confirmation."

- **A. Repo-type variant — LANDED** (2026-08-16): `repo_remote =
  Git | Hg | Tar` (+ `None` for local-only forks) with per-kind fetch
  tools — git (clone/fetch/worktrees), hg (clone/pull/update in place),
  tar (curl+unpack); spec-check handles each (forge check for Git/Hg;
  archive = warning-grade origin). The framework is no longer hardcoded
  to git.
- **B. Repo contents + retire the old booleans — LANDED** (2026-08-16):
  1. `source_repo.artifacts : artifact_id list` (what the repo's tree
     builds) — populated on all constructors (z3/llvm = lib + in-tree
     bindings; zarith = binding only, GMP off-tree; the pattern-A/sqlite/
     ssl repos = [a_lib]).
  2. Checker invariant (pinned as `repo_model.contents_invariant`):
     a non-source artifact's `Repo` provider must appear in that
     repo's contents.
  3. Legacy `has_build_*` consumers RETIRED: z3/llvm's dead
     `mk_runner_spec` + `lib_cmd_of_source`/`binding_dir_cmd_of_source`
     helpers deleted (−810 lines); the pre-A5 CI path
     (`z3_ci_spec`/`llvm_ci_spec`) turned out to be table-based already
     — nothing to migrate.
  4. On-tree/off-tree = derived from the contents lists (display only).
- **C. The 3-way per project**:
  1. **C1 zarith — LANDED** (2026-08-16): the new `Repo_axes of
     source_repo list` provider — a repo FAMILY covering the channels
     of one artifact. Each repo's `version` record projects into the
     source row's store pins (channel preserved), so every repo is an
     identity-bearing scenario and `--thin` (Subset [Stable]) drops the
     dev repos. `Canary_opam_binding` gains `sources : source_repo list`
     (stable first, dev, then a labeled fork when one exists) and its
     realization dispatches per scenario — each fetch materializes ITS
     channel's worktree. zarith now runs 2 scenarios
     (source-fetched-1.14 / source-fetched-master). Pins:
     `repo_model.axes_pins` (enumeration + identity + dispatch) +
     the registry zarith block. NOTE: the old "waits on
     Fetched-source-id" blocker turned out to be obsolete — the
     store-pin machinery (2026-08-12) already provides the identity;
     see the Fetched-source-id item in status_project.md.
  2. **C2 z3/llvm — LANDED** (2026-08-16): the arbipher forks are
     labeled third repos (`label = Some "arbipher"`, identity-bearing
     `id = "arbipher"` — the 2026-08-13 fork↔official collision is
     resolved by design), the source rows are `Repo_axes
     [stable; latest; fork]`, and each project's realization dispatches
     on the SOURCE placement's pinned id (`z3/llvm_source_for_assignment`
     — the pre-C2 lib-channel proxy retired; the dev/stable ROW split
     stays driven by the lib provision in `realize_from_rows`). The
     Built-lib↔source coupling in `assignment_ok` relaxed to CHANNEL
     equality (exact-id equality was right while sources were ambient;
     with per-repo pins it would kill both dev build chains). Each
     project now enumerates 5 scenarios: 3 all-Fetched source worlds +
     2 dev build chains; `--thin` keeps the stable chain only.
  3. **C3 bugfix-commit REGRESSION refs — LANDED** (2026-08-17, the
     z3 #10549 case): a repo can pin a commit just BEFORE a known fix
     (`z3_source_pre_10549`, `ref_ = "bc4585e0b"` — the parent of the
     PR's first commit; standalone checkout, ISOLATED build dir per
     mk_locals' variant TODO). The regression CHECK is the
     `Cmake_install.assert_staged` primitive (prefix-relative paths
     that must exist after `cmake --install` — the named failure
     signature "OCAML INSTALL MISSING" lands in `install_fail.log`);
     the pre-fix world's Install_lib carries a DECLARED expected
     failure (the historical-bug shape — xfail on confirm), every
     other ref expects success. The ref-selection config:
     `source_ref_level = All_refs | Refs of ids` on the enumeration
     config (a post-product filter beside shadow_filter, keyed on the
     source placement's pinned id; unpinned/absent sources pass
     through), the CLI's `--refs a,b` on action + spec (the regression
     pair run: `--refs latest,pre-10549` = 4 scenarios). z3 now
     enumerates 7 scenarios (4 all-Fetched + 3 dev chains); the batch
     stays thin (channel subset, unaffected). Two verification
     findings became fixes: Install_lib now depends on the built
     bindings (the merged rules stage the OCaml package — the old
     order staged only META), and the assert is gated to OFFICIAL
     repos (a fork's in-flight tree isn't held to the merged fix's
     contract). The warm-mask lesson again: a warm "latest PASS" from
     a PRE-MERGE clone had to be forced cold before the fix's
     confirmation counted.
- **D. The web viewer** — after the 3-way (the UI over the commands).
- **The datatype→functions conversion** (user, 2026-08-16): `Canary_opam_binding.t` should NOT
  be a datatype — at most functions producing the general types
  (project_run, configs, actions). Decoupled from C1; the next task.

Recommended order: B → C1 → C2 → D (B first: the contents field
migrates the CI path before any 3-way work touches it).

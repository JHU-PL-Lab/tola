# Tola Project Memory

Working memory for this repo, one note per file; CLAUDE.md loads this
index. A rule about the code or the repo's process belongs in CLAUDE.md
or the doc it points to, not here, and a note that repeats one is
deleted.

## Working with the user
- [Bottom-up over top-down](feedback_bottom_up_design.md) — grow by concrete increments; design docs consolidate last
- [Design forks: discuss first](feedback_design_forks.md) — discuss a design fork before changing code; record the analysis as a design doc or a status to-do
- [Patient with new actions](feedback_patient_with_new_actions.md) — a change adding an action or step is planned and parked, not landed in passing (2026-09-29)
- [Writeup consolidation](feedback_writeup_consolidation.md) — uniformity eventually, not now: queue draft revisions in draft_drift.md rather than fixing them ad hoc
- [Stage by file name](feedback_stage_by_name.md) — never `git add` a directory; the drafts under doc/canary/research/ stay unstaged (2026-10-01)
- [Protect contrib/ caches](feedback_protect_contrib_cache.md) — never rm contrib/*: the z3 and llvm builds there are heavy
- The user reads Chinese; project comments may use Chinese terms.

## The user's environment
- [CAML_LD_LIBRARY_PATH shadows fresh dlls](gotcha_caml_ld_shadow.md) — bytecode dll search beats -dllpath; opam stublibs can fake an "upstream break" (z3 2026-08-13)
- [Reaching the mac runner](gotcha_mac_runner_reachability.md) — DHCP moves its IP, mDNS connects only ~50%, push host→mac over ssh
- [Two sessions, one working tree](gotcha_shared_working_tree.md) — a checkout switches the branch under the other session and `git add -A` sweeps its files; check `git reflog`

## On hold
- [Diagram model refactor](project_diagram_model_refactor.md) — a model-first rewrite of canary_diagram.ml's Mermaid output

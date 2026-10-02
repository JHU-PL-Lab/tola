# Tola Project Memory

Working memory for this repo, one note per file; CLAUDE.md loads this
index. A rule about the code or the repo's process belongs in CLAUDE.md
or the doc it points to, not here, and a note that repeats one is
deleted.

## Working with the user
- [Bottom-up over top-down](feedback_bottom_up_design.md) — grow by concrete increments; design docs consolidate last
- [Design forks: discuss first](feedback_design_forks.md) — discuss a fork before changing code; a general finding outranks finishing the task
- [Patient with new actions](feedback_patient_with_new_actions.md) — a change adding an action or step is planned and parked, not landed in passing
- [Writing the paper](feedback_writeup_consolidation.md) — queue drift in draft_drift.md, one home per concept, the user writes the prose, small steps
- [Stage by file name](feedback_stage_by_name.md) — never `git add` a directory; the drafts under doc/canary/research/ stay unstaged
- [Protect contrib/ caches](feedback_protect_contrib_cache.md) — never delete under contrib/: the z3 and llvm builds there take hours
- The user reads Chinese; project comments may use Chinese terms.

## The user's environment
- [CAML_LD_LIBRARY_PATH shadows fresh dlls](gotcha_caml_ld_shadow.md) — guard a build step's OCaml self-check with absolute paths
- [Reaching the mac runner](gotcha_mac_runner_reachability.md) — its IP moves (find it with ARP), mDNS is unreliable, push from the host
- [Two sessions, one working tree](gotcha_shared_working_tree.md) — a checkout moves the other's branch, `git add -A` sweeps its files; check `git reflog`

## On hold
- [Diagram model refactor](project_diagram_model_refactor.md) — one model with merge and expand operations for canary_diagram.ml's Mermaid output

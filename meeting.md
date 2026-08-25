tiny with canary-backend:
  `dune exec src/bin/canary_main.exe -- tiny list`
  `dune exec src/bin/canary_main.exe -- tiny run`
  `dune exec src/bin/canary_main.exe -- tiny status`

## Tiny project generation enumeration

They share the same logic to loop with:
  - scenarios determined by language and binding mechanism, which is from lib building to app use
    - inside per sceanrio
      - for each related artifact, mutate it to get bad artifact
      - have good but incompabitle artifacts

## Canary-banckend

c_lib -> sys_pkg_c      -\
                          --build_opam... -> run_lib -> build_wrap_lib -> use_wrap_lib
binding_lib -> opam_pkg_ -/


artifact (src, lib, pkg, ...)
  record-view: getter, setter, modify


real-world bugs ---> tiny bug
  regression testing

dual-view (bad thing):
    top-down: scenario to artifact
    artifact ... scenario introducted (root of caused), detected (oracle testing, )

        sum-bad 
not a complete detection

working thread
code:
    framework
            examples
doc:


## Aug 9-15
plan (finish 1-2 this week):
1. finish tiny code part, flush the updated taxonomy to draft
2. give you a readable draft
3. having more real-world **projects**

## Aug 16-22

1. More project landings
`sqlite`, `z3`(with regression testing), `cario`, `libffi`, `zlib`, `zstd`, `ssl` (`canary result`)
- currently a project spec contains two major components, an artifact list with identity and providers, and a command runner specication which can be templated on artifacts and hardcoded
  - we can express official prebuilt, official repo with reference commits (stable, regression commit, latest, using worktree), on-tree (a repo field) and off-tree (standalone artifact).
  - project spec checking is a collecting and reporting on whether we have enough information on the artifact kind (provider c lib side and each language+mechanism user side).
    - heuristics: system package manager > official prebuilt download > conda-forge prebuilt download > building-from-source (some subtlity here)
    - a forked repo is necessary for other library source or binding source for fix
  - _how to check project-side_

2. The selected project are precursors for more projects in opam, and the opam projects are also examples for cooperations between project managers which are on both sides (`canary/base/canary_binding_decl.ml`).
   - messy conf-<pkg>, see in opam package survey `opam.md`
   - dep too restricted, old bug remains and need admin effort; dep too relaxed, new bug may appear
     - need to bypass some conf-<pkg> if it's hardcoded

3. _what to check and how to check agreement-side_
   - a fully registry `surface/canary_contract_registry.ml`
   - workflow: fill a matrix for
     - artifact, tools, binding mechanism
     - actions, runtime behavior
   - will result in a canary agreement registry, that canary will use this and the project spec to pick
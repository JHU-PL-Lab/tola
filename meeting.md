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

plan (finish 1-2 this week):
1. finish tiny code part, flush the updated taxonomy to draft
2. give you a readable draft
3. having more real-world **projects**
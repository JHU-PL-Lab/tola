# Worklog

1. Add a project _tiny-full_, a project using stardard _canary_ project spec, under general scenarion exploration. It's a sample project that shares the same form as a general project, while it can reuse the beliefs that the preview `tiny` established.

background: Canary has a component `tiny` which built upon a naive sum library [tiny.c](canary/examples/tiny/c/src/tiny.c). The project constructs every possible building and use scenarios. These _scenario_ includes good scenario where a series of actions just work, and bad scenario where we mutates each artifacts generated at each steps. The mutation is looped both for actions e.g. fetch, build, run, publish (to do) and the involved artifacts including source (for lib and for binding), header, binding, direct app (the code use the binding), and indirect app (the code use the module wraping the binding). These are used to test directly with shell commands. Now we made _tiny-factory_, which generates many canary projects _tiny1_ that each runs just one designed scenario. Canary by default tries all enumerations, but _tiny1_'s spec has only one possible scenario to run.

There is a **gap** between _tiny-factory_/_tiny1_ with a general exteral project to test e.g. `sqlite` because there is no smoke testing to test canary enumerations itself. So I made `tiny-full`, which is literally merged `tiny1` into one _canary_ project.

Here are two enumerations:
- _tiny-factory_, per-scenario per-artifact mutation. static-determined `scenario_specs` in [](src/canary/projects/canary_tiny_scenario.ml). flat scenarios
- _tiny-full_, just reuse general canary enumeration `dune exec src/bin/canary_main.exe -- status tiny-full`.

(what confuses human confuses ai...)

In the beginning, the tiny-full explored more scenarios than tiny-factory, e.g. compiling binding with a bad header and a  bad library, which was not in the tiny-factory's handwritten since per-artifact can have at most #artifact cases. However, it is not a problem if the canary faithfully implements fail fast, so we shall have an invariant stated `#cases_of_tiny_full = #cases_of_tiny_factory`.

2. Evident-based `sqlite` checking.
_we need two examples to make general functions_ (with tiny-full and sqlite)
...

3. Incremental concept and code unification
(cleanup)
command to inspect
testcase to keep invariant


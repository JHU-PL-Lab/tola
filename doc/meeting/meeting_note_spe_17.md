# Worklog

1. Integrated actions in enumeration from agreement checking and remove legacy steps on ad-hoc checking, including
- Old code has separate inspectation action to _parse_ artifacts (.h, .so. .ml) into cached json and separate actions to _check_ the parse result. 
  - It doesn't align with the agreement philosophy that a checking is a complete action to reading something against some truth.
  - lowering the cache for parse as a low-level op, and the cache is artifact-(and world)-based, rather than action-based. It can be reduced even both checkings do the same inpectation.
- Old code has `<action>_post` as hook trigger to run. The concrete action is registered in the project spec
- Old code has special actions `probe_lib` (which _checks_ the parse result), `probe_binding_<lang>` (which runs the sanity-check examples)
  - the above two is not uniformed on when to check and the meaning for probe.
  - working on treating <action>_post a dispatching moment, so `build_lib`, `fetch_lib`, `install_lib` can both have a `<action_post>` but invoke the same set of lib checking.
  - 

2. Solidating the agreement table, which lies between the doc and the code. The kind of agreements are
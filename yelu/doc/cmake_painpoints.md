# CMake Pain Points — and How Yelu Addresses Them

This document records specific cmake design decisions that are hostile to
static analysis, LLM synthesis, and human reasoning, alongside the yelu
design choices that address each one.

The goal is not to criticize cmake — it is a remarkably capable tool that
evolved organically over 20+ years. The goal is to identify the *properties*
that make it hard to work with, and use those as design constraints for yelu.

---

## 1. Variable Names and Values Are the Same Type

**The cmake problem.**
In cmake, a variable name and a variable value are both plain strings.
The distinction is purely positional — determined by where in a command the
argument appears, not by any syntactic marker on the argument itself.

```cmake
set(myvar hello)         # "myvar" is a variable name (write target)
set(other ${myvar})      # "${myvar}" is a value (read expansion)
list(APPEND mylist ${x}) # "mylist" is an identifier; "${x}" is a value
foreach(i IN ZIP_LISTS a b) # "a", "b" are variable names read by cmake
```

A reader (human or LLM) must know each command's argument schema to
distinguish identifiers from values. There is no local syntactic cue. An LLM
generating cmake must memorize per-command conventions rather than inferring
from the argument itself. Mistakes are silent: passing a variable *value*
where a variable *name* is expected does not error — cmake just uses the
string as-is.

**What yelu does — implemented.**
Yelu introduces `yelu_cvar` as a distinct type for cmake variable names.
All command arguments that are variable *identifiers* — whether written to
(output positions) or read by name (e.g., list-variable inputs) — take
`yelu_cvar`. All arguments that are *values* take `yarg`.

```ocaml
yc_set        : yelu_cvar -> yarg list -> yelu_exp
yc_foreach_zip: yelu_cvar list -> yelu_cvar list -> yelu_exp -> yelu_exp
yc_string_uuid: ... -> yelu_cvar -> yelu_exp   (* out is an identifier *)
```

A caller who passes a value (`yarg`) where an identifier (`yelu_cvar`) is
expected gets a compile-time type error. The distinction that cmake makes
implicit and per-command is made explicit and uniform across all yelu APIs.

This was a deliberate design refactor: prior to 2026-04-17, output positions
used `out : string` and mutation targets used `cvar : yarg` — both too weak
to enforce the identifier/value distinction. The refactor changed all such
positions to `yelu_cvar` uniformly across `lang_yelu.ml`, `lang_yelu_compile.ml`,
`lang_yelu_utils.ml`, and all call sites. The surface API now uses `ycvar "x"`
for identifiers and `ystr "v"` / `ycref "x"` for values — locally distinguishable
without consulting command documentation.

**Note on cmake's six namespaces.**
cmake actually has six independent namespaces (Variable, Cache, Target,
Command, Test, Policy). `yelu_cvar` covers the Variable namespace. Yelu also
has `Ytarget` for the Target namespace. The others (Cache, Command, Test,
Policy) are either handled as strings or not yet represented — recorded as
future work.

---

## 2. Implicit List Splitting on Semicolons

**The cmake problem.**
cmake's fundamental data type is a string. Lists are strings where elements
are separated by semicolons. This means a string like `"a;b;c"` is silently
interpreted as a three-element list in list contexts. Forgetting to quote
`"${myvar}"` when the variable might contain semicolons causes silent
argument splitting.

```cmake
set(myvar "a;b;c")
message(STATUS ${myvar})    # prints three separate args: "a" "b" "c"
message(STATUS "${myvar}")  # prints the single string "a;b;c"
```

This is perhaps cmake's most notorious footgun. The rule "always quote variable
references" is widely repeated but frequently forgotten, and the failures are
silent (wrong behavior, no error).

**What yelu does (partial).**
Yelu's `Ycs_val` strings that contain whitespace or special characters are
automatically emitted as `Quoted` args by the compiler. This prevents the
most common whitespace-splitting issue. Full list-vs-string distinction is a
future design problem (Tier 5+): yelu does not yet have a typed `list` vs
`string` distinction at the yelu-AST level.

---

## 3. Output Variables Are Named by the Caller, Not the Command

**The cmake problem.**
cmake commands that produce output require the caller to supply the *name*
of the variable to write into. This is necessary because cmake has no
return values — output is communicated through the variable namespace.
But it means every call site carries an identifier that is purely a
plumbing detail, not part of the computation.

```cmake
string(LENGTH "${mystr}" len_var)   # "len_var" is caller-chosen plumbing
math(EXPR result "${a} + ${b}")     # "result" is caller-chosen plumbing
```

This is a consequence of cmake's design, not a bug. But it means:
- LLMs generating cmake must track variable names across steps
- Humans must invent names for intermediate results
- The computation and the plumbing are interleaved

**What yelu addresses (future).**
The compile-time `Ylet` binding in yelu is a step toward separating
computation from plumbing: a yelu program can bind intermediate results
to compile-time names without those names leaking into the cmake output.
Full expression composition (where yelu commands return values that can be
nested directly) is a Tier 5+ language design goal.

---

## 4. `if()` Boolean Semantics Require Policy CMP0012

**The cmake problem.**
In cmake without `cmake_policy(SET CMP0012 NEW)`, the strings `ON`, `YES`,
`TRUE`, `1` are *not* treated as boolean true in `if()` conditions. They
evaluate as false because cmake's old behavior treats unrecognized strings
as variable names, and those variables are undefined (empty = false).
The new behavior (CMP0012 NEW) is correct and expected, but it is not the
default in script mode (`cmake -P`).

```cmake
set(eq ON)
if(${eq})            # evaluates FALSE without CMP0012 NEW
if(${eq} STREQUAL "ON")  # works correctly regardless of policy
```

This surprises everyone the first time. LLMs trained on cmake snippets that
assume modern policy behavior generate subtly broken code when run in older
or script contexts.

**What yelu does.**
Yelu's `Ytruthy` condition is safe for non-boolean strings (empty/non-empty
check). For cmake commands that return `ON`/`OFF` (e.g., `string(JSON EQUAL
...)`), the correct test is `Ystrequal (ycref "var", ystr "ON")` — an
explicit string comparison that works under any policy. Yelu never generates
bare `if(${var})` for boolean-valued cmake variables; it always uses an
explicit comparison. Future work (Y11): emit `cmake_policy(SET CMP0012 NEW)`
automatically when `Ytruthy` is used on a cmake variable.

---

## 5. ERROR_VARIABLE Convention: NOTFOUND Means Success

**The cmake problem.**
cmake commands that accept `ERROR_VARIABLE` set the variable to an error
message on failure. On *success*, they set it to `NOTFOUND` — not to empty
string. This is consistent with cmake's `find_*` convention (where
`VAR-NOTFOUND` means "not found"), but it is counterintuitive: a check for
"no error" must compare against `NOTFOUND`, not `""`.

```cmake
string(JSON result ERROR_VARIABLE err GET "${json}" key)
if(NOT err STREQUAL "NOTFOUND")   # correct success check
  message(FATAL_ERROR "error: ${err}")
endif()
```

Most developers expect `""` to mean success. The cmake docs do not
prominently document this behavior, and it is easy to get backwards.

**What yelu does (future).**
Yelu wraps `ERROR_VARIABLE` commands with a cleaner API. A future design
could return a result type (success/failure) rather than exposing the raw
error variable convention to callers, hiding the NOTFOUND/error-message
distinction entirely.

---

## 6. `string(JSON SET ...)` Value Must Be a JSON Literal

**The cmake problem.**
`string(JSON ... SET json path value)` requires `value` to be a valid JSON
literal — a number (`42`), a JSON-quoted string (`"\"hello\""`), a boolean
(`true`/`false`), or `null`. Passing a plain cmake string like `hello`
fails silently (returns `NOTFOUND`). The cmake docs describe this but it is
easy to miss: the mental model of "pass a cmake string" is wrong here.

```cmake
string(JSON r SET [=[{"x":1}]=] y hello)       # fails — not a JSON literal
string(JSON r SET [=[{"x":1}]=] y [=["hello"]=]) # works — JSON string literal
string(JSON r SET [=[{"x":1}]=] y 42)           # works — JSON number
```

**What yelu does (future).**
A typed `yelu_json_value` type (distinct from `yarg`) for the `value`
argument of `yc_string_json_set` would prevent passing a plain string.
Currently the API accepts `yarg` and relies on the caller to pass an
appropriate JSON literal via `ystr_raw`.

---

## Summary

| Pain point | cmake behavior | Yelu response |
|---|---|---|
| Variable name vs value | implicit by position | `yelu_cvar` vs `yarg` distinction (this doc, §1) |
| List splitting on `;` | silent, context-dependent | auto-quoting of `Ycs_val`; full fix is future |
| Output variable plumbing | caller-named, interleaved | `Ylet` for compile-time bindings; expression compose is future |
| `if()` boolean policy | CMP0012 NEW required | explicit `STREQUAL "ON"` comparisons; Y11 policy preamble |
| `ERROR_VARIABLE` success value | `NOTFOUND` not `""` | future: result-type API over raw error_var |
| JSON SET value type | must be JSON literal | future: `yelu_json_value` type |

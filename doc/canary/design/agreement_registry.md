# Tool-Grounded Agreement Catalogue for Cross-Language Binding Checks

**Kind: proposal.** The producer landed (`agreement/canary_agreement_registry.ml` carries the rows); the catalogue's remaining rungs are open. **Landed when** every agreement in the catalogue resolves to a check that can ground it.

> **Where an agreement gets EVALUATED is an open question this catalogue
> inherits** (2026-08-30):
> [`check_evaluation.md`](check_evaluation.md). Canary's checks are OCaml
> closures on a step, so they cannot cross into a backend that only emits
> YAML — the GH backend renders `check_pre`/`check_post` zero times, and a
> green CI job today means only "every command exited 0". If an agreement
> is to be checkable wherever a world runs, the catalogue's natural
> projection is onto CHECK ACTIONS ([`../status.md`](../status.md),
> `[Pre; Action; Post]`), and the IR question — does a check action carry
> its implementation or its meaning? — is worth settling here rather than
> after.

## Status and Purpose

This document is an intermediate design note for consolidating the checking logic scattered across the cross-language binding project.

The project already enumerates many possible **provider × binding × consumer worlds**, including different provider provisions, binding implementations, direct applications, and applications using an additional wrapper layer. Those worlds then exercise ordinary lifecycle actions such as fetch, build, publish, fetch-from-package, install/stage, and use/probe.

The purpose of this document is narrower:

> **Systematically catalogue the agreements that can be checked around those actions, and define the principles by which those agreements are observed.**

This document is therefore about the **checking model**, not the enumeration engine and not the cache implementation.

The existing project already has a contract registry, firing rules, fixtures, and an action-centred belief matrix. The current registry is intended to make the checking belief explicit and printable rather than leaving it scattered across project-specific tables and helper code.

The work here sits one level above that implementation. Its goal is to establish a more systematic catalogue from which concrete registry rows can later be derived.

**Merged 2026-08-21.** This is now the single doc: the former
`contract_registry.md` was folded in and deleted. Its material landed in
three places — the confirmed sections below absorbed what belongs to
them (§0.3/§0.4 falsification and the ladder, §1 the implemented
presence/identification instances, §2.1 the surface-role table);
the **implemented module** moved to Appendices A–C; and catalogue
drafts whose home is a section still under review wait in **Appendix
D**, tagged with their intended destination. Nothing was inserted into
an unconfirmed section — the outline stays the review spine.

---

# Progress Outline

* [x] **0. Scope and checking philosophy** (0.6 taxonomy added 2026-09-01)
* [x] **1. Resource presence and identification**
* [ ] **2. Artifact surfaces and surface correspondence**

  * [x] 2.1 Syntactic versus realized/semantical surface
  * [ ] 2.2 Surface projections
  * [ ] 2.3 Provider-side surface chain
  * [ ] 2.4 OCaml C-stub surface chain
  * [ ] 2.5 Python C-extension surface chain
  * [ ] 2.6 Python ctypes surface chain
  * [ ] 2.7 Cross-surface agreements
  * [ ] 2.8 Static observation and later dynamic confirmation
* [ ] **3. Representation and marshalling agreements**
* [ ] **4. Lifetime and ownership agreements**
* [ ] **5. Resolution agreements**
* [ ] **6. Dependency and denotation agreements**
* [ ] **7. Transformation and packaging preservation**
* [ ] **8. Behavioral agreements**
* [ ] **9. Project- and version-derived agreement discovery**
* [ ] **10. Blame and result interpretation**
* [x] **10a. The doc/code bridge and its harness**
* [ ] **11. Mapping the catalogue back to actions and the registry**

Current discussion should resume from **§2: Artifact surfaces**.

---

# 0. Scope and Checking Philosophy

## 0.1 Current binding mechanisms in scope

For now, the catalogue only needs to support three concrete binding mechanisms:

### OCaml through C stubs

```text
C provider
→ C header
→ OCaml C stub source
→ compiled stub artifacts
→ OCaml implementation/interface
→ compiled OCaml artifacts
→ OCaml consumer
```

### Python through a CPython C extension

```text
C provider
→ C header
→ extension C source
→ compiled extension module
→ Python package/module
→ Python consumer
```

### Python through ctypes

```text
C provider
→ C header
→ ctypes declarations
→ Python module
→ Python consumer
```

Other mechanisms such as Rust FFI, JNI, P/Invoke, CFFI, and OCaml Dynlink may be added later, but they should not complicate the current design.

---

## 0.2 Tool-grounded rather than fully formal

The checking model does not attempt to formalize the complete semantics of the compiler, linker, loader, package manager, or language runtime.

Instead, the project treats these systems as externally observable mechanisms and consumes results that developers can inspect directly.

Typical evidence includes:

```text
source inspection
binary inspection
compiler success/failure
linker success/failure
language compiler metadata
package-manager queries
loader behavior
import/load behavior
runtime output
```

The general principle is:

> Prefer an observable tool result over reconstructing the full semantics of the tool that produced it.

For example, a compiler is not modeled operationally. If the relevant question is whether a generated stub conforms to a header, the compiler's result can serve as one confirmation of that agreement.

Likewise, the existing design already follows the principle that successful execution of a tool is insufficient by itself when the produced artifact can be inspected. The product should be inspected and compared with the declared expectation.

---

## 0.3 Agreements are falsifiable observations

The checking system should remain explicitly falsification-oriented.

A successful check means:

> no counterexample was found using this observation.

It does not imply complete compatibility.

The existing registry already adopts this stance: a symbol check can falsify compatibility when a required symbol is missing, while successful symbol inspection cannot prove that no other runtime requirement exists.

This principle should remain global across the expanded catalogue.

Three consequences carried over from the registry design:

* **Phrase each claim as its falsifier.** An agreement's one-line
  statement should name what a counterexample looks like — "every
  symbol the binding declares is exported by the lib", not "the binding
  needs exactly the lib's symbols". The row text is then directly
  testable.
* **The declared watchlists are the falsifier's ammunition.** What a
  check can catch is bounded by what the project declared
  (`c_api.functions`, the surface watchlists): a richer declaration is
  a stronger disprover, and an empty one silently checks nothing.
* **Instrumentation narrows blindness without creating proof.** An
  interposition recorder can show what a consumer actually requested in
  a given run; requests beyond the declaration are counterexamples, but
  "nothing beyond" holds only for the runs observed.

---

## 0.4 Earliest observation, later confirmation

An agreement may be observable at several stages.

For example:

```text
header declaration
      ↓
binary inspection
      ↓
link
      ↓
load
      ↓
run
```

If a mismatch can already be detected through static artifact inspection, that is generally the preferred detector.

A later compile, link, load, or execution result can then provide additional confirmation of the same underlying agreement.

This corresponds to the existing regression-driven ladder:

1. inspect one artifact,
2. compare two surfaces statically,
3. check an action postcondition,
4. exercise the meeting,
5. execute the program.

The project already states that failures should be caught at the earliest practical rung because later runtime failures are slower and provide weaker blame information.

Two rules follow, and both are worth keeping explicit:

* **Escalate only when forced.** An agreement observable at rung 1 must
  not be left to rung 5; a run-time failure is slower, flakier, and
  blames less precisely.
* **A rung-5-only failure is a finding about the FRAMEWORK**, not only
  about the project under test. It names a surface we do not yet
  inspect, and is therefore the main generator of new catalogue
  entries.

A useful interpretation is therefore:

```text
static observation
      ↓
static meeting
      ↓
dynamic meeting
      ↓
runtime confirmation
```

These are observation depths, not separate agreement families.

---

## 0.5 Cache behavior is outside the agreement model

The project is intentionally cache-friendly.

Many enumerated worlds may share the same provider artifact, binding artifact, inspection result, or action result. Idempotent actions can therefore be cached and reused.

However:

> **Caching is an execution-layer property, not an invariant or agreement.**

The agreement catalogue should not depend on how checks are memoized or reused.

It should only describe:

```text
what should hold
what evidence is relevant
where it becomes observable
what later observation may confirm it
```

The execution engine is separately responsible for avoiding duplicated work.

---

## 0.6 What to check, how to check it, and why it is a check at all

Two questions, in the order they are useful:

```text
1. WHAT is checked, and HOW   → the target and the method   (§0.6a)
2. WHY is it a check at all   → the source of the belief     (§0.6b)
```

The first is concrete and comes first. The second decides whether a
check is obligatory and who is blamed when it fails.

### 0.6a The check: target and method

| target                | method                                                                                   | what it can see                                                                    | what it cannot                                                           |
| --------------------- | ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| **a solo artifact**   | an inspector — `nm`, `readelf`, `ocamlobjinfo`, `dir()`, a parser                        | what this one artifact presents, and whether it matches what was declared about it | anything relational; anything about the other side                       |
| **several artifacts** | inspect each, then COMPARE — still only artifacts, nothing runs                          | that two recorded or declared surfaces disagree                                    | what the toolchain will actually do with them                            |
| **a running result**  | observe the outcome of running a TOOL (compiler, linker, loader) or of running TEST CODE | that the join or the behaviour really happened, in this world                      | only the observable result — never the mechanism that produced it (§0.2) |

Two consequences of stating it this way:

* **comparing two artifacts and joining them are different targets.**
  Static comparison is the second; the join actually happening — a link,
  a load — is a running result. Different cost, different failure mode,
  different blame.
* **one agreement can have checks at several targets.** That is §0.4's
  ladder restated: `c_types_agree` compares header and stub signatures,
  and the compiler's verdict later confirms the same agreement. The
  agreement is one; the observations are many, and the earliest that can
  hold it should.

### 0.6b Why it is a check at all — the source of belief

**Every check compares an artifact against a claim.** Nothing is
checkable in isolation: a C library exporting 462 symbols is not wrong
until something says it should export 463. So the answer to *why is this
a check* is always **who claims it**, and that decides two things the
target and method do not:

| #   | source of belief            | the claim                                                                  | obligation                                                   | blame when it fails                                                                                     |
| --- | --------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| 1   | **self / format**           | the artifact is well formed, or satisfies a universal property of its kind | **always** — costs nothing, needs no declaration             | the artifact                                                                                            |
| 2   | **declaration**             | the project said this artifact provides X                                  | **always**, wherever a declaration exists                    | the artifact **or the declaration** — a row must say which it trusts                                    |
| 3   | **peer artifact**           | another artifact records that it needs X                                   | **always**, wherever both are present                        | the pair: *direction* if they differ by version, the **cooperation** if they differ by packaging (§6.5) |
| 4   | **sibling world**           | the same artifact, obtained another way, disagrees                         | when a world holds two provisions — canary's 2×2 always does | neither artifact: the **provisioning** (§6.3)                                                           |
| 5   | **prior version**           | this version differs from the last                                         | when a version axis exists                                   | the change — a regression indicts the newer side                                                        |
| 6   | **upstream statement**      | the project asserts it itself — a manifest, docs, its own tests            | opportunistic — only if upstream said something              | strong: the project contradicted **itself**                                                             |
| 7   | **behavioural expectation** | a recorded observation says what running does                              | the residue — nothing earlier could express it               | the world that ran; the weakest blame                                                                   |

**Obligation follows availability, not cost.** A check is obligatory
when its source of belief is present in every world. Rows 1–3 always
have their source; row 4 has it whenever a world holds two provisions,
which canary's 2×2 guarantees; rows 5–6 depend on the project offering a
version axis or a statement; row 7's source — an observed run — does not
exist until everything before it has passed.

**Why row 2 carries so much weight.** The language tools — compilers,
linkers, version scripts, install rules — are BLACK BOXES with no
bit-wise operational semantics we can reason about. A linker may
silently drop a version script; a build system may not re-run; an
install may skip a rule. So we never trust a tool's exit code beyond
its marker postcondition: we inspect the ARTIFACT it produced and
compare it against what was declared. That is why the declaration
source dominates the catalogue, and why the same skeleton — *inspect
the product, compare to the declaration* — recurs at every lifecycle
stage, from the built lib to the staged image.

One consequence worth keeping: **the same belief can appear twice, once
recorded and once predicted.** `symbol_exported`'s solo cell is the
same comparison as the status table's watchlist verdict
(`watchlist N/N` / `⚠ MISSING`); the registry is where the two views
reconcile.

**Blame follows the claimant.** A failing check means **either the
artifact or the claim is wrong**, and the source names the claim's
author. Two rows need care:

* **row 2** is the one that gets misread. A conformance failure does not
  automatically indict the artifact — the declaration may be stale. A
  row must state which side it treats as authoritative, or its finding
  is unattributable.
* **rows 3–4** hold the ncurses case: both artifacts correct, no version
  between them, so canary's forward/backward *direction* has nothing to
  resolve and the blamed party is the cooperation, or the provisioning.
  **Direction is a tiebreaker within row 3, not a universal rule.**

### 0.6c The catalogue — every check we run or have proposed

Status: **wired** = a live check; **row** = a registry row without an
implementation; **proposed** = named in this document, no row yet.

#### Target 1 — a solo artifact, via an inspector

| check                                | falsifier                                                 | method                               | source                                                      | status                                                           |
| ------------------------------------ | --------------------------------------------------------- | ------------------------------------ | ----------------------------------------------------------- | ---------------------------------------------------------------- |
| `symbol_exported` (lib-only)         | a declared `c_api` function is missing from the built lib | `nm -D` vs the decl                  | declaration                                                 | wired                                                            |
| `api_surface_complete` (c2)          | a watchlisted name is absent from the user-facing surface | `.mli` / `dir()` vs the watchlist    | declaration                                                 | wired                                                            |
| `soname_denotes_needed` (lib-only)   | the built lib's elf soname ≠ the declared soname          | `readelf -d` vs the decl             | declaration                                                 | wired                                                            |
| `symbol_versions_present` (lib-only) | a declared version tag is not exported                    | `nm -D` version nodes vs the decl    | declaration                                                 | wired                                                            |
| action markers                       | the action's declared output never appeared               | `test -f`                            | declaration                                                 | wired                                                            |
| PM pin check                         | the installed package is not at the pinned version        | the PM's own query                   | declaration                                                 | wired                                                            |
| pinned-ref freshness                 | the checkout is not at the ref it claims                  | `rev-parse HEAD` vs the ref          | declaration                                                 | wired                                                            |
| repo contents                        | the tree lacks what its row says it provides              | file existence                       | declaration                                                 | wired                                                            |
| staged completeness                  | a declared artifact did not stage                         | `test -f` under the prefix           | declaration                                                 | wired (hand list; deriving it from the declared surface is open) |
| portability of a staged binary       | a staged artifact still contains a build-tree path        | grep the artifact's metadata/strings | **self** — installable binaries must be relocatable         | proposed (§7)                                                    |
| inspect-JSON integrity               | the summary does not have the kind it claims              | the parser                           | **self**                                                    | wired (warns)                                                    |
| spec maturity                        | a project's own declaration is incomplete                 | `canary spec-check`                  | **self** — applied to a declaration rather than an artifact | wired                                                            |

#### Target 2 — several artifacts, inspected and compared

| check                            | falsifier                                                                                                  | method                                    | source                 | status                           |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------- | ----------------------------------------- | ---------------------- | -------------------------------- |
| `symbol_exported` (pair)         | the stub's undefined refs are not covered by the lib's exports                                             | `nm` both, set difference                 | peer                   | wired                            |
| `c_types_agree` (c6)             | header and stub disagree on a signature                                                                    | typed inspects, compare                   | peer                   | wired                            |
| `soname_denotes_needed` (pair)   | the lib's soname is not what the consumer recorded                                                         | `readelf -d` both                         | peer                   | wired                            |
| `symbol_versions_present` (pair) | the consumer requires a version node the provider does not export                                          | version maps, compare                     | peer                   | wired                            |
| `c1_lag_note`                    | *(a warning, not a failure)* the consumer uses a small fraction of the provider's surface — possibly stale | set sizes                                 | peer                   | wired                            |
| `closure_satisfiable`            | a recorded `NEEDED` has no provider in this world                                                          | `readelf -d` vs the world's objects       | peer                   | row                              |
| `no_duplicate_implementation`    | two identities in the closure are one implementation, or one absorbs another                               | symbol sets + version namespaces          | peer                   | row                              |
| `denotation_across_worlds`       | one soname names different implementations in the two provisions                                           | compare the object each soname names      | **sibling world**      | row                              |
| staged parity                    | the staged image differs from the build tree beyond declared transforms                                    | symbol/version diff, build vs staged      | sibling world          | proposed (§7)                    |
| header-as-oracle                 | a consumer's declared types contradict the header it wraps, at a later action                              | typed header vs the consumer's surface    | peer                   | proposed (§2)                    |
| DWARF signatures                 | the built lib's compiled signatures contradict the declared header                                         | `readelf --debug-dump=info` vs the header | declaration            | proposed (§2, when DWARF exists) |
| export-set diff                  | a version changed what it exports under a consumer's feet                                                  | two versions' `nm` output                 | **prior version**      | proposed (§9)                    |
| upstream manifest                | the artifact contradicts a typed API manifest the project ships                                            | manifest vs `nm`/headers                  | **upstream statement** | proposed (§9; torch has one)     |

#### Target 3 — a running result, of a tool or of test code

| check                           | falsifier                                                                      | method                             | source                 | status                                             |
| ------------------------------- | ------------------------------------------------------------------------------ | ---------------------------------- | ---------------------- | -------------------------------------------------- |
| build/link verdict              | the pair does not compile or link                                              | the compiler's/linker's exit + log | peer                   | wired (as step outcome)                            |
| `behavior_matches` (c3)         | the probe's trace differs from what was recorded                               | run, grep the log                  | behavioural            | row (disabled)                                     |
| `repack_preserves_api` (c7)     | the user layer is not a sound repacking of the stub layer                      | run the binding probe              | behavioural            | row (stubbed)                                      |
| `repack_complete` (c8)          | the repack lost something the original had                                     | —                                  | behavioural            | row (blocked on c6+c7)                             |
| smoke load                      | the lib does not load, or a declared function cannot be entered                | link a minimal program, run it     | declaration            | proposed (§0.6c; decl-derived, exercises the LOADER) |
| `interposition_winner`          | the definition that wins for a shared symbol is not the one built against      | `LD_DEBUG=bindings`                | peer                   | row                                                |
| recorder shim                   | *(evidence, not a verdict)* what the consumer actually requested/resolved      | interposition, log                 | —                      | proposed (§6.7)                                    |
| fake provider                   | the consumer breaks against a provider that satisfies the declared surface     | plant a lib, run                   | declaration            | proposed (§10.3)                                   |
| direct-vs-indirect differential | `app_direct` and `app_via_helper` disagree                                     | run both, compare                  | behavioural            | proposed                                           |
| prebuilt self-sufficiency       | a prebuilt needs env beyond the library path to run                            | run with only the declared env     | declaration            | proposed (§6.8)                                    |
| translated test                 | a natively-asserted behaviour does not survive translation through the binding | run the translation                | **upstream statement** | proposed (§0.6d)                                   |
| project's own suite             | upstream's tests fail against this world                                       | run the suite                      | upstream statement     | proposed                                           |
| regression pin                  | a past bug reappears                                                           | re-run its witness                 | prior version          | proposed (§0.4)                                     |

Reading the catalogue: **the same `.so` appears at all three targets and
under four different sources.** The file does not determine the check;
the claim does, and the target only says where you can see it.

### 0.6d Three sources also GENERATE checks

Rows 5–7 can manufacture candidates, not merely judge them: version
diffs propose *did this export set change under a consumer's feet*; an
upstream manifest proposes a typed expectation; and a behavioural
expectation can be **derived** rather than written — most sharply as the
**translated test**:

> A behaviour asserted natively should survive translation through the
> binding. A divergence is a binding fault, because the native side
> already established the expected answer.

Strong for two reasons — the expected outcome is *given* rather than
guessed, and one native suite yields as many binding checks as it has
cases — and it composes with the differential shape: a direct and a
via-helper translation of one native test should agree with each other
as well as with the native result. Its cost is the translation, so it
belongs with §9's derivation work.

---

# 1. Resource Presence and Identification

The first two candidate families, existence and identity, are better treated as a single lower-level capability.

They are foundational observations used repeatedly by higher-level agreements such as resolution, dependency closure, packaging, and version compatibility.

The core abstraction is:

```text
resource reference
       ↓
resource substrate
       ↓
presence + identification
```

The module answers two basic questions:

### Presence

```text
Can the referenced resource be observed?
```

### Identification

```text
What observable facts identify the resource that was found?
```

This module does not itself decide compatibility.

It provides evidence that later agreements consume.

---

## 1.1 File-system resources

Example:

```text
/path/to/libfoo.so
```

Presence can be checked externally through the file system.

Identification may expose facts such as:

```text
path
file type
metadata
hash
binary format
other inspection-derived facts
```

More specialized binary information can later become part of the artifact's surface.

The important point is that existence of a file and the properties of the file are grounded in observable file-system and inspection results.

---

## 1.2 Web and URI resources

A resource may instead be referenced through:

```text
URL
URI
remote object identifier
```

Presence may mean:

```text
the resource resolves
the resource can be fetched
```

Identification may include:

```text
resolved/final URI
content identity
content hash
returned metadata
```

Again, this is substrate-level evidence.

---

## 1.3 Package-manager resources

Package-level existence cannot always be reduced to file-system existence.

A package manager has its own resource model and commands for answering questions such as:

```text
does package X exist?
is package X installed?
what package/version is installed?
what files belong to this package?
```

Therefore a package-level check should use the package manager's own observable instructions when the resource being discussed is a package.

A check such as:

```text
package X exists
```

is different from:

```text
file Y exists
```

even when package X eventually materializes file Y.

The two can be composed:

```text
package metadata/instruction
        ↓
expected package contents
        ↓
contained resource presence
```

---

## 1.4 Extensible resource substrates

The abstraction should not be tied to file systems or package managers.

Other possible substrates include:

```text
KV store
artifact store
object store
cache
package registry
remote build result store
```

The same pattern applies:

```text
reference
  ↓
lookup
  ↓
present / absent

reference
  ↓
identify
  ↓
observable resource facts
```

This is useful because higher-level checks should not need to care whether a resource was obtained from a local path, package manager, URI, artifact registry, or cache.

---

## 1.5 Relationship to resolution

Presence/identification and resolution should remain separate.

Presence/identification answers:

> What resource is here?

Resolution answers:

> Given a resolution mechanism, which resource was selected?

Resolution can therefore repeatedly invoke the lower-level identification machinery.

For example:

```text
loader chooses resource R
        ↓
identify(R)
        ↓
compare actual resource with intended resource
```

The same idea applies to:

```text
compiler include lookup
linker library lookup
package lookup
language module lookup
dynamic loading
```

Details of paths, ABI compatibility, versions, loader policies, and search order are intentionally deferred to later sections.

---

## 1.6 What canary implements today

The capability already exists in the framework, scattered across the
execution layer rather than named as one module. Its instances:

| instance                                                                                       | substrate                   | presence                            | identification                                                            |
| ---------------------------------------------------------------------------------------------- | --------------------------- | ----------------------------------- | ------------------------------------------------------------------------- |
| per-action markers (`marker_of_action`: `source.ok`, `build.ok`, `install.ok`, `probe.log`, …) | file system                 | the action's declared output exists | the file itself; nothing finer                                            |
| pinned-ref freshness                                                                           | git working tree            | the checkout is there               | `rev-parse HEAD` equals the declared ref (works for SHAs and tags)        |
| PM pin-check                                                                                   | package manager             | the package is installed            | the installed VERSION equals the declared pin                             |
| repo-contents invariant                                                                        | git tree                    | the tree is there                   | it contains what its declared row says it provides                        |
| staged completeness (`assert_staged`)                                                          | file system, install prefix | the staged file exists              | (currently a hand list; deriving it from the declared surface is a to-do) |

Two observations from that table:

* Most instances today check **presence** and only some check
  **identification** — markers in particular prove that a file appeared,
  never that it is the right one. That asymmetry is exactly why the
  execution layer had to add a separate spec-fingerprint gate: presence
  alone cannot tell a current artifact from a stale one.
* The instances live as action postconditions, which is the right
  execution shape, but they are not yet reachable as a *capability*
  that higher agreements can invoke — §1's abstraction is what would
  make resolution (§5) and dependency closure (§6) able to reuse them.

---

# 2. Artifact Surfaces

This is the current active section.

The term **surface** already exists in the project design. The original registry used `Surface`, `Meeting`, and `Execution` as descriptive roles, where `Surface` asks what one artifact presents at its boundary.

The term is useful and should be retained, but the current discussion makes a more detailed distinction inside the surface category.

---

## 2.1 Syntactic surface and realized surface

The project distinguishes two broad kinds of artifact surface.

### Syntactic surface

A **syntactic surface** is information directly visible in source-level artifacts.

Examples include:

```text
C header declarations
C stub source
OCaml .ml source
OCaml .mli source
Python extension source
Python ctypes declarations
Python source modules
```

The syntactic surface captures what the source claims or explicitly expresses.

---

### Realized / semantical surface

A compiled or otherwise realized artifact also exposes an observable surface.

Examples include:

```text
C shared-library exports
undefined references
symbol versions
binary metadata
compiled OCaml interface metadata
compiled OCaml module metadata
compiled extension metadata
runtime-loadable entry points
```

These facts usually require platform or language-specific inspection tools.

Internally, this has been described as the **semantical surface** because it represents the interface that actually survived realization rather than the one merely visible in source syntax.

However, the word `semantic` can also imply full program semantics in PL terminology.

A clearer public name may therefore be:

```text
syntactic surface
realized surface
```

If `semantical surface` is retained internally, the document should explicitly define it as:

> the realized, tool-observable interface of an artifact, not the full behavioral semantics of the program.

### The five named surface roles

The manuscript already names five surfaces along exactly this axis
(presence: syntactic/realized) plus a side (native/binding). They are
the vocabulary the checking code writes against, so the catalogue
should reuse the identifiers rather than invent parallel ones:

| id   | name             | side    | kind      | what it is                                                               |
| ---- | ---------------- | ------- | --------- | ------------------------------------------------------------------------ |
| Sf.1 | `native_header`  | native  | syntactic | declared C interface — signatures, structs, macros                       |
| Sf.2 | `native_lib`     | native  | realized  | the compiled `.so`/`.dylib` — defined symbols, `@@VER`, SONAME, NEEDED   |
| Sf.3 | `binding_stub`   | binding | syntactic | the stub-facing declarations — `external`, `argtypes`, `PyMethodDef`     |
| Sf.4 | `binding_header` | binding | syntactic | the user-facing module signature — `.mli` vals, Python module names      |
| Sf.5 | `binding_lib`    | binding | realized  | the compiled binding — `.cmxa` + stub `.a`, the cext `.so` (ctypes: n/a) |

A **runtime observation** (a probe's trace) is deliberately NOT one of
the five: it observes execution, not an artifact's boundary. It is
referred to as `Trace` where a row needs to name it.

### Where the evidence comes from

Each inspect input the checking code consumes maps to exactly one
surface role — this is what grounds a check in an artifact rather than
in a tool:

| inspect input                         | surface role (side)                            |
| ------------------------------------- | ---------------------------------------------- |
| `C_stub`                              | Sf.3 (binding)                                 |
| `Native_lib`                          | Sf.2 (native)                                  |
| `Ocaml_mli` / `Python_attrs`          | Sf.4 (binding)                                 |
| `Abi_surface`                         | Sf.5 (binding)                                 |
| `Versioned_exports` / `Versioned_req` | Sf.2 (native) / Sf.5 (binding)                 |
| `Typed_header` / `Typed_binding_stub` | Sf.1 (native) / Sf.3 (binding)                 |
| probe output                          | `Trace` — a runtime observation, not a surface |

Note that Sf.5 is empty for ctypes (nothing is compiled on the binding
side), which is the structural reason that mechanism loses its
static falsifiers — the point §2.6 develops.

---

## 2.2 Fundamental surface agreement

The first general agreement in this section is:

> **The realized surface produced by a toolchain should correspond to the relevant syntactic surface from which it was produced.**

Conceptually:

```text
syntactic surface
       ↓ realization
realized surface
```

This relationship is more general than an individual symbol or type check.

Different checks simply inspect different projections of the two surfaces.

For example:

```text
header declares foo
       ↓
library exports foo
```

is a **name/symbol projection**.

Likewise:

```text
header declares the signature of foo
       ↓
compiled artifact exposes compatible type information
```

is a **type/signature projection**, when such information is observable.

This suggests that symbol agreements and type agreements belong under a common concept of **surface correspondence** rather than necessarily being independent top-level categories.

---

## 2.3 Provider-side surface chain

The C provider already has at least two important surfaces.

### Source-level provider surface

Typically represented by the C header:

```text
foo.h
```

It may expose:

```text
function names
parameter types
return types
struct declarations
enum declarations
constants/macros where relevant
calling-related annotations
visibility declarations
```

This is the strongest source-level description of the provider API currently available to the binding.

---

### Realized provider surface

The compiled C library:

```text
libfoo.so
```

has a different observable surface.

Depending on available tooling and build information, it may expose:

```text
exported symbols
undefined symbols
symbol kind
symbol versions
dynamic metadata
relocations
debug/type information when available
```

The existing document already exploits this difference. It notes that headers carry type information while compiled artifacts often require tools such as `nm` or DWARF inspection to recover parts of the realized interface.

This naturally creates provider-side correspondence checks:

```text
header
  ↕
compiled C library
```

---

## 2.4 OCaml C-stub binding surfaces

For the OCaml mechanism, the binding itself exposes several different surfaces.

### C stub source

For example:

```text
foo_stubs.c
```

This is simultaneously:

* a consumer of the C provider,
* an implementation of the native side of the OCaml binding.

Its syntactic surface may contain:

```text
native symbol references
C types
marshalling operations
OCaml runtime API use
primitive entry points
```

This surface can be compared directly with the C header.

---

### OCaml interface source

For example:

```text
foo.mli
```

This is the language-facing declared API.

It says what the binding promises to OCaml consumers.

Example:

```ocaml
val foo : int -> string
```

---

### OCaml implementation source

For example:

```text
foo.ml
```

This implements the language-side API.

It may:

```text
declare external primitives
wrap primitives
rename operations
compose several native calls
expose only a subset
add language-side behavior
```

The OCaml compiler already provides an important tool-based agreement:

```text
.ml conforms to .mli
```

The checking framework should consume this result rather than recreate OCaml's own type checker.

---

### Compiled OCaml artifacts

The binding may then produce:

```text
.cmi
.cmo
.cmx
.cma
.cmxa
.cmxs
stub .o
stub .a
stub .so
```

These artifacts still expose substantial observable information.

Existing project tooling already inspects these artifacts using the relevant OCaml and native-object tools.

Therefore the compiled artifacts should be treated as realized surfaces rather than opaque binaries.

This creates potential correspondence edges such as:

```text
.mli
 ↓
.cmi
```

```text
.ml / external declarations
 ↓
compiled module metadata
```

```text
stub source
 ↓
stub object/archive/shared-library references
```

The exact catalogue of projections still needs to be completed.

---

## 2.5 Python C-extension surfaces

The Python C-extension mechanism has a similar but distinct chain:

```text
C header
    ↓
extension C source
    ↓
compiled extension shared object
    ↓
Python-visible module/package
```

Relevant surfaces include:

### Source surface

```text
extension C implementation
Python package/module source
```

### Realized native surface

```text
compiled extension .so
native symbol references
extension initialization entry point
binary dependencies
other inspectable metadata
```

### Runtime Python surface

```text
imported module
visible names/objects
package-level exports
```

This mechanism therefore supports surface correspondence at several points:

```text
header
↔ extension source

extension source
↔ compiled extension

compiled extension
↔ runtime Python module
```

---

## 2.6 Python ctypes surfaces

ctypes has a shorter artifact chain:

```text
C header
    ↓
Python ctypes declarations
    ↓
Python module
    ↓
runtime calls
```

There is no native binding compilation stage.

The consumer-side syntactic surface therefore includes constructs such as:

```text
library name/path declaration
function lookup
argtypes
restype
structure declarations
callback declarations
```

The absence of a binding compilation stage is significant.

For example, a type mismatch may have:

```text
source inspection
        ↓
no compiler confirmation
        ↓
runtime call
```

rather than the:

```text
source inspection
        ↓
C compilation
        ↓
link/load
        ↓
runtime call
```

available to the C-stub mechanisms.

This is an example of mechanism affecting **where an agreement can be observed**, while the underlying agreement remains the same.

---

## 2.7 Surface correspondence as the common model

The general form is:

```text
Artifact A exposes Surface A
Artifact B exposes Surface B

Agreement:
projection(Surface A)
corresponds to
projection(Surface B)
```

Possible projections include:

```text
names / symbols
members / modules
types / signatures
references / requirements
metadata
```

For example:

```text
C header ↔ C library
C header ↔ binding stub
binding source ↔ compiled binding
OCaml .mli ↔ .cmi
binding interface ↔ wrapper interface
compiled binding ↔ runtime-visible module
```

The exact projection catalogue remains the next item to develop.

---

## 2.8 Surface inspection versus resolution

A key boundary should be maintained.

Suppose static inspection finds that an artifact requires symbol or library `X`.

That belongs to **artifact surface inspection**:

```text
artifact says:
    "I require X"
```

A later loader observation answers a different question:

```text
loader resolved X to resource R
```

That belongs to **Resolution**.

Likewise:

```text
compiled artifact records dependency D
```

belongs to the artifact's surface.

```text
runtime loaded /path/to/D
```

belongs to resolution and dependency closure.

The distinction is useful because many later agreements repeatedly consume previously inspected surfaces.

---

# 3. Representation and Marshalling Agreements

**Status: pending.**

This section should cover value preservation across the native/language boundary after the surface correspondence model is stabilized.

Likely subjects include:

```text
integer width and signedness
floating-point values
strings
NULL / option / None
struct and record representation
enum/tag mappings
pointer representation
error representation
callbacks
```

This section should remain distinct from type correspondence because compatible type shapes do not guarantee correct runtime value representation.

---

# 4. Lifetime and Ownership Agreements

**Status: pending.**

Likely subjects include:

```text
borrowed versus owned pointers
returned-object ownership
input lifetime
callback lifetime
GC rooting
Python reference ownership
double free
leaks
use after free
repeat-call stability
```

These agreements are expected to depend more heavily on dynamic probes and instrumentation than the earlier surface agreements.

---

# 5. Resolution Agreements

**Status: pending.**

Resolution should build on the lower-level resource presence/identification capability.

The central question is:

> Given a resolution mechanism, which resource was actually selected?

Potential resolution domains include:

```text
compiler header discovery
link-time library selection
dynamic-loader library selection
OCaml package/module discovery
Python module discovery
ctypes library lookup
```

Path rules, version selection, ABI-related selection, and shadowing should be discussed here rather than inside the basic presence/identity layer.

---

# 6. Dependency and Denotation Agreements

**Status: drafted 2026-09-01, pending review.** Written from a confirmed
instance rather than from design. Absorbs the former
`closure_shape.md` and Appendix D.2.

> **Renamed** from "Dependency-closure" (user, 2026-09-01): *closure*
> names the symptom — two objects loaded together — not the fault. The
> fault is that a library IDENTITY stopped denoting one implementation.

## 6.0 The three views of a dependency

A dependency exists in three forms, and every agreement in this family is
a disagreement between two of them:

| view         | what it is                                    | observed by                                                                  |
| ------------ | --------------------------------------------- | ---------------------------------------------------------------------------- |
| **declared** | what the project/packaging says is needed     | `pkg-config --libs`, opam `depends`, depexts, the `pm_dep_gate`              |
| **recorded** | what the built artifact froze into itself     | `readelf -d` (`NEEDED`, `RPATH`/`RUNPATH`), `.cmxa` linkopts, wheel metadata |
| **resolved** | what the loader actually bound, in this world | `LD_DEBUG=libs,bindings`, `ldd`, the run itself                              |

The recorded view is pivotal: it is **frozen at build time in the
provider's shape**, and it is what travels when the artifact is deployed
somewhere else.

**The triple is universal, and it repeats per hop** (user, 2026-09-01).
It is not a C-library notion — it describes any package dependency, and
a chain has one instance of it at every link:

```text
app  →  helper/wrapper package  →  binding  →  native lib
 └ declared ┘ recorded ┘ resolved      (once per arrow)
```

Two consequences the `app_via_helper` wiring already makes concrete:

* a chain can carry **several declared and recorded sets at once** —
  each hop froze its own, in the world where that hop was built;
* those sets may have been **resolved on a different machine** than the
  one that finally runs. The end user resolves again, against whatever
  their world provides, and only that last resolution decides what runs.

So "it worked where it was built" is evidence about one machine's
resolution, not about the recorded dependencies being portable — which
is exactly what §6.1 is an instance of.

## 6.1 The instance that made this section (ncurses)

Two providers of one library — apt 6.4 and conda-forge 6.6 — agree on
soname, on all 463 exported symbols, and on every ELF version node.
`c1`, `c4`, `c5` pass, correctly. **The vendored world segfaults.**

The two packagers divide the same implementation differently. Debian
ships one tinfo (`libtinfo` *is* the wide build); conda-forge ships two
(`libtinfo` narrow, `libtinfow` wide). A consumer built in the Debian
world records `libtinfo.so.6` and in the conda world that name resolves
to the *narrow* object, which then sits beside the wide one the
provider's own `libncursesw` pulls transitively. Interposition gives the
narrow object's globals to everybody; narrow and wide disagree about
`cur_term`'s layout; the wide code dereferences a narrow record and dies.

Every name resolves. Nothing is absent. Full report, reproducer and
remediation: [`../project/report_ncurses_libtinfo.md`](../project/report_ncurses_libtinfo.md).

**Stated as the fault rather than the symptom:**

> `libtinfo.so.6` denotes the WIDE ABI on Debian and the NARROW ABI on
> conda-forge. One identity, two implementations, depending on the
> world. The duplicate load is what that failure looks like from inside
> the process.

This also explains the fix — a rename gives the wide ABI its own
identity, restoring denotation — and it exposes an asymmetry worth
keeping:

```text
two names → one implementation     BENIGN   (Debian's proposed alias)
one name  → two implementations    HAZARD   (the ncurses case)
```

## 6.2 What the artifacts alone say (measured 2026-09-01)

Both tinfo objects, conda-forge 6.6:

```text
sonames             libtinfo.so.6   vs  libtinfow.so.6   (305016 vs 305368 bytes)
WIDE minus NARROW   NCURSESW6_* × 10 version nodes
                    _nc_copy_termtype2  _nc_export_termtype2  _nc_fallback2
                    _nc_free_termtype2  _nc_read_entry2      (all TERMTYPE2 ops)
NARROW minus WIDE   NCURSES6_*  × 11 version nodes
both define         cur_term  SP  _nc_globals  _nc_prescreen  ttytype
```

**The soname is the decisive fact** (user, 2026-09-01): it is the
artifact's declared IDENTITY, and identity is what this family is about.
`libtinfo.so.6` and `libtinfow.so.6` are two identities; the question is
what each denotes in a given world.

The rest — disjoint version namespaces, the five `TERMTYPE2` operations,
the same globals defined twice — is INTERFACE detail. It is genuine and
it explains why confusing the two is fatal rather than merely untidy,
but it answers a different question: *what API status does this
implementation present?* That belongs to the surface family (§2), where
it is useful for checking a binding against the C library it was built
for. It is not what identifies the object.

What no artifact carries: that `TERMTYPE`/`TERMTYPE2` are two layouts of
the SAME record (a header-level Sf.1 fact), and that the two objects are
alternative spellings of one implementation. **The difference is
artifact-visible; the sameness is not.**

## 6.3 The agreements

Identity first, falsifier-phrased:

| agreement                              | falsifier                                                                                                                                          | reads                                       |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| **denotation across worlds**           | a recorded identity denotes a DIFFERENT implementation in the deploy world than in the build world                                                 | the same soname's object in both provisions |
| **no duplicate implementation**        | the resolved set contains two identities that are one implementation (alternative spellings), or one that statically absorbs another (containment) | the shipped objects                         |
| **closure satisfiable**                | a recorded name has no provider in this world                                                                                                      | recorded vs the world's objects             |
| **interposition winner** *(candidate)* | the definition that wins for a shared symbol is not the one the consumer was built against                                                         | resolved (`LD_DEBUG=bindings`)              |

The first is the primary one, and **canary is unusually well placed to
run it**: a 2×2 world holds BOTH provisions, so the check is a static
comparison of what one soname denotes on each side — available before
any probe runs, with no loader involved. Nothing about it is
ncurses-specific.

None of these is `c4`: `c4`'s inputs (`soname`, `c_runtime`, `cxx_abi`)
are scalars a provider states about ITSELF, whereas these relate a
consumer's recorded list to a provider's layout, or one world's layout
to another's.

## 6.4 What the fix costs, measured on this machine

Ubuntu today has **no `libtinfow` at all** — one file, and both `.pc`
files name it:

```text
ncursesw.pc   Libs: -lncursesw -ltinfo      ← wide consumer, name "tinfo"
ncurses.pc    Libs: -lncurses  -ltinfo      ← narrow consumer, SAME name
/usr/lib/x86_64-linux-gnu/libtinfo.so.6 → libtinfo.so.6.4   (one object)
```

That is the denotation failure at its source: **the name carries no ABI
information**, and Debian's single object serves both `.pc` files.

Under the report's recommendation only `ncursesw.pc` changes to
`-ltinfow`; `ncurses.pc` keeps `-ltinfo`, and Debian ships
`libtinfow.so.6` as a symlink onto the same object so both names resolve.
One cost the report does not state: a binary built on the NEW Debian
records `libtinfow.so.6` and will not run on an older Debian lacking the
alias — additive for existing binaries, backward-incompatible for new
ones.

## 6.5 Blame — the cooperation is the blamed party

The report's verdict: *"The crash needs both halves; neither party is
broken alone… It is the interaction that fails."* The consumer did the
correct thing — it asked pkg-config and used the answer. Both libraries
are correct, and the versions are drop-in compatible: repoint the name
and the same binaries run green with no rebuild.

So blame attaches to **neither artifact but to their cooperation**
(user, 2026-09-01) — an acceptable verdict, not a gap: the failure IS a
runtime behaviour of the combination, even though its evidence is
static. This is the case that narrowed §10.2's direction rule, which now
states both meet outcomes: direction when the sides differ by version,
the cooperation when they differ by packaging. In §0.6's terms the check
is *meet / packaging* with origin *peer artifact*.

Canary's job here is not to fix upstream — the report is already
addressed to Debian — but to PREDICT: the world becomes `xfail[cN]`
with a derived reason instead of an undeclared segfault.

## 6.6 The second form, and the method lesson

The sweep (`../raw/closure_shape_sweep.sh`, run before any code, 2026-08-25)
found the hazard is not an ncurses peculiarity and that it has two forms:

| form                     | signature                                                                 | instance          |
| ------------------------ | ------------------------------------------------------------------------- | ----------------- |
| **alternative spelling** | overlap covers ≥80% of BOTH sides — one implementation, two names         | ncurses (4 pairs) |
| **containment**          | ≥80% of the smaller only — a large object statically absorbed a small one | sundials (82)     |

cairo, libffi, zlib and zstd score zero on both, so the landed pairs are
not retroactively in doubt — the check they passed was narrower than we
thought, and they pass the wider one too.

**The method lesson, worth keeping as a rule**: the first, coarser
detector (bare symbol overlap) fired on cairo — *it would have
"confirmed" the proposal for the wrong reason*. A threshold heuristic is
for FINDING candidates; an identity fact or a declaration is what a
contract READS. This is §0.3's falsification discipline applied to the
detector itself.

## 6.7 Hidden dependencies (from Appendix D.2)

The wider family this section owns — what `nm` on one artifact does not
reveal:

* **transitive `NEEDED`** — a dependency of a dependency that must be
  present at load; `DT_RUNPATH` does NOT apply transitively (unlike
  `DT_RPATH`), so a lib that works standalone can fail as a dependency;
* **`dlopen`'d plugins** — resolved by name at run time, invisible to
  static inspection (exactly what the ctypes/cffi mechanisms ARE);
* **symbol interposition** — another loaded object providing the same
  symbol first; ncurses is interposition doing precisely what it is
  specified to do;
* **weak symbols and default version resolution** — which definition
  wins when several exist.

These are the home for the interposition-shim RECORDER: it produces
evidence for the **resolved** view of §6.0 without issuing a verdict
(§10.3).

## 6.8 Open steps

1. ~~sweep the existing pairs~~ — done 2026-08-25, not falsified (§6.6).
2. Declare the alternative-spelling fact on `native_api` beside
   `soname` — now a CONVENIENCE that names which identities are
   alternatives, since §6.3's denotation check needs only the two
   worlds' objects.
3. Add the contract row: denotation across worlds first (cheapest, and
   canary holds both provisions), then no-duplicate-implementation
   covering both forms; firing at `Probe_binding` over a non-`Fetched`
   lib provision, `source = Inspection`.
4. `Canary_prebuilt.env` — the same world first failed differently:
   conda's `libtinfow` has its build prefix compiled in for terminfo
   data, so a prebuilt may need env beyond the library path
   (`TERMINFO_DIRS`). It is a relocation failure, so the agreement
   itself belongs to §7; only the declaration is owed here.
5. ncurses' vendored world becomes `xfail[cN]`, and D6 lands at Level B
   instead of positive-only. Tracked in
   [`../project/issues.md`](../project/issues.md).

---

# 7. Transformation and Packaging Preservation

**Status: pending.**

Any lifecycle transformation such as:

```text
build → stage
stage → package
package → publish
publish → fetch
fetch → install
```

may preserve some properties while changing the carrier.

The existing staged-parity work is already an instance of this broader pattern. The current document explicitly describes staged parity as the same artifact-checking family one lifecycle stage later.

This section should generalize that idea.

---

# 8. Behavioral Agreements

**Status: pending.**

Behavior should remain the deepest observation layer.

Likely categories include:

```text
function reachability
return values
state changes
error behavior
callback behavior
repeat execution
wrapper faithfulness
direct-vs-indirect differential behavior
```

Execution should remain a last resort when earlier artifact or meeting observations can already falsify the relevant agreement.

---

# 9. Project- and Version-Derived Agreement Discovery

**Status: pending.**

Candidate agreements may originate from several sources:

```text
artifact structure
binding mechanism
language/platform tool behavior
project declarations
project code
version information
historical regressions
```

Version differences are particularly useful because they can generate candidate agreements without requiring a full semantic model.

For example:

```text
stable provider exports {a, b, c}
dev provider exports    {a, c}
```

immediately suggests a symbol-surface compatibility question for existing bindings.

Likewise:

```text
header signature changes
SONAME changes
dependency-set changes
binding interface changes
```

can generate candidate checks.

This should later feed the agreement catalogue, while the project-specific declaration remains the oracle for facts that cannot be inferred generically.

---

# 10. Blame and Result Interpretation

**Status: pending review.** Carried over from the registry design,
where it was an open axis; the outline gained a section for it
2026-08-21.

For every check, on every agreement, two questions need an answer that
does not depend on the reader's intuition:

> What does a passing result mean?
> What does a failing result mean, and which artifact is indicted?

## 10.1 A pass means something different at each observation depth

A pass is never "compatible"; it is bounded by what was observed:

```text
one artifact, statically   → this artifact's presented facts cover the
                             declaration. Says NOTHING about the other side.
two surfaces, statically   → these two declarations agree. Says nothing
                             about what the toolchain will actually do.
an action postcondition    → the action produced its declared output.
                             Presence, not correctness.
the meeting                → this pair joined under the conditions
                             exercised — a fact about the RELATION.
the run                    → this execution behaved, bounded by the
                             coverage of the program that ran.
```

Writing the pass meaning next to each agreement is what stops a green
matrix from being read as "verified".

## 10.2 Failure blame is direction-shaped

A single-artifact failure blames that artifact: what it presents
contradicts what it declared.

A failure of a PAIR is ambiguous at the point of detection — the
symbol is missing, but is the provider too old or the consumer too
new? The framework already computes the answer as a scenario property:
`mismatch_direction` (Forward / Backward).

```text
forward  (consumer newer than provider) → the consumer asked for too
                                          much; the binding/app is indicted
backward (provider newer than consumer) → the provider dropped or changed
                                          something; the lib is indicted
```

**Blame assignment now lives in §0.6**, where it is read off the source
of the claim: a failure means the artifact or the claim is wrong, and
the source names the claim's author. What remains this section's own is
the part that is not about attribution — the depth-of-pass reading
(§10.1) and the instrumented cases (§10.3).

The one rule this section contributed, and the amendment the ncurses
case forced (2026-09-01):

**Direction resolves a pair failure only when the two sides differ by
VERSION.** When they differ by PACKAGING — both artifacts correct, the
versions drop-in compatible, and the conventions disagreeing about how
one implementation is named and divided — no direction exists, and the
blamed party is the **cooperation** (§6.5). So the meet band has two
blame outcomes, not one:

```text
meet failure, versions differ    → direction decides (forward: consumer,
                                    backward: provider)
meet failure, packaging differs  → the COOPERATION; neither artifact is
                                    broken alone
```

So **direction is a tiebreaker within one source (peer artifact), not a
universal rule** — §0.6's table is where every other case is decided.

## 10.3 Instrumented observations shift blame deliberately

Two future instruments invert the usual reading, and each needs its
blame statement fixed in advance:

* a **fake provider** (a planted lib satisfying the declared surface)
  moves blame to the consumer's robustness — or to the declaration the
  plant was built from;
* a **recorder** (interposition that logs what was actually requested
  or resolved) blames nobody: it produces evidence, not a verdict, and
  its output feeds §5 and §6.

## 10.4 Open questions

* Does every agreement row need its own blame field, or does blame
  derive uniformly from (evidence shape × direction)?
* Can a single-artifact failure ever be direction-resolved — e.g. the
  artifact IS the provider in a backward world?
* Where a version skew exists between two evidence sources (headers
  from a source repo, lib from a package), the row must record which
  artifact's version the oracle assumed, or blame lands on the wrong
  side (§2.3, §5).

---

# 10a. The doc/code bridge — and the harness that keeps it honest

**Landed 2026-09-01.** The catalogue is not only something the code is
cited BY; it is meant to guide the code, so the two must be checkably
aligned (user).

**The bridge.** Every agreement — implemented or merely stated — carries
a stable **slug** and the **section that defines it**:

```ocaml
{ cr_slug = "soname_denotes_needed"; cr_doc = "§6"; … }   (* implemented *)
{ pp_slug = "denotation_across_worlds"; pp_doc = "§6.3"; … }  (* proposed *)
```

`Canary_agreement_registry.all_agreements` unions both into one list, so
there is a single place that answers *what does canary believe, and
where is it written down*. The slug is the name that survives the
`c1..c8` renaming settle (§0), so citations do not rot when the ids go.

**Proposed rows make the holes visible.** An agreement this catalogue
states but the code has not implemented gets a row with
`status = proposed` and a `needs` field, rather than being absent —
the registry lists its own gaps, the same principle as the belief
matrix's `~` marks. §6.3's four agreements are the first entries.

**The harness.** Three pins in the layer suite, the third of which reads
this file:

| pin                                      | property                                                               |
| ---------------------------------------- | ---------------------------------------------------------------------- |
| `agreements.slugs_unique_and_named`      | slugs unique and non-empty; every entry has a claim and a `§`-anchor   |
| `agreements.every_contract_has_an_entry` | the implemented rows and the proposals both appear in `all_agreements` |
| `agreements.doc_anchors_exist`           | **every declared section EXISTS as a heading in this document**        |
| `agreements.doc_cross_refs_resolve`      | **every prose `§` reference in this document resolves to a heading** — lines naming another `.md` are skipped, since their `§` belongs to that document |

The last two are the alignment properties: renaming a section, or citing
one that was never written, fails `canary project-test`. Both were
verified by falsification rather than trusted — pointing a row at a
section number that does not exist turns the anchor pin red, and the
cross-reference pin found five stale references on its very first run —
four section numbers left pointing at their pre-merge meanings, plus a
sentence whose example number read as a citation. That is the class of
rot a document meant to guide code accumulates silently.

(Those numbers are deliberately not written here with their sigil: the
pin reads any such token as a citation, which is a small illustration
of the rule that a harness constrains the prose it checks.)

**What it does not yet check** (worth naming so the harness is not read
as stronger than it is): that the *claim text* matches the section's
prose, that every agreement the doc describes has a row (only the
reverse direction is enforced), and that a `Proposed` row's `needs` is
still accurate. Those want a richer harness — the natural next step is
the doc growing machine-citable agreement blocks.

---

# 11. Mapping Back to Actions and the Registry

**Status: pending.**

Once the agreement catalogue is sufficiently complete, concrete agreements should be mapped back into the existing action-centred framework.

The existing design already models the main checking space as:

```text
agreement/contract × action
```

with mechanism and provision refining where a check applies rather than creating a full Cartesian-product matrix.

Each final agreement row should eventually state something close to:

```text
name
claim                          (phrased as its falsifier, §0.3)
origin
relevant surfaces/artifacts    (Sf.1..Sf.5 / Trace, §2.1)
earliest observation point     (the ladder rung, §0.4)
tool/result used as evidence
later dynamic confirmation
applicable mechanism
applicable provision
minimal falsifier / fixture    (executed ahead of any project run, App. A)
pass meaning + blame           (§10)
current implementation status
```

The registry then becomes the executable projection of this larger catalogue.

---

# Current Working Position

The discussion should continue from **§2: Artifact surfaces**.

The next concrete question is:

> **What projections make up an artifact surface?**

The current candidates are:

```text
names / symbols
members / modules
types / signatures
references / requirements
metadata
```

The next pass should determine:

1. whether these projections are complete;
2. which projections exist on the provider side;
3. which projections exist for OCaml C stubs;
4. which projections exist for Python C extensions;
5. which projections exist for Python ctypes;
6. which pairs of surfaces produce useful concrete agreements.

The inspection tools themselves already exist in the project and have their own tests, so the next step should focus on **what is being observed and compared**, rather than re-cataloguing tool implementations.

---

# Appendix A. The implementation, and the views onto it

> What canary checks is stated three ways, on purpose, and this appendix
> holds the two that are mechanical. §0.6c is the CATALOGUE — every check
> with its target, method, source and status, which is the view to read
> first. A.2 is the same belief as the code computes it, printed rather
> than transcribed. A.3 is the same belief filtered per artifact, which
> is the view that shows where the coverage is thin.


> Carried over from `contract_registry.md` (merged 2026-08-21). This is
> the EXECUTABLE projection of the catalogue as it stands today —
> §11 absorbs it when the mapping-back section is worked through.
> Nothing here is a proposal; it is what the code does.

## A.1 — Where things live

Since the table moved into the registry (2026-09-01), the module IS the
definition and its own docstrings are the detail. This map is what the
appendix needs to carry:

| file | holds |
|---|---|
| `agreement/canary_agreement_registry.ml` | **the table** — one row per agreement (slug, doc anchor, claim, reads, firing, expectation source, fault tags) · the proposed rows · `all_agreements` · the counterexample fixtures · the belief matrix (`belief_matrix` / `pp_belief_matrix` / `fill_list`) · the queries (`predicted_contains_any_v2`, `predicted_by_agreement_v2`, `skipped_checks`, `inputs_of_agreement`) |
| `agreement/canary_agreement_run.ml` | the predicate IMPLEMENTATIONS only — `c1_predict` … `c8_predict`, the decl-comparison predicts, the loaders, the CLI |
| `agreement/canary_agreement.ml` | the vocabulary and the pure comparators — `inspect_input`, `agreement_id`, `agreement_check`, `check_c_compat`, `check_abi`, … |

Dependency direction is **registry → run → agreement**, with no cycle,
which is why the queries had to travel with the table. Adding an
agreement means editing one file.

**Producer-first, and still additive.** Nothing in `project/` or `main/`
reads the registry yet; its only consumers are the pins. The per-project
`*_agreement_bindings` tables still drive the live lowering, and they
are deleted only behind byte-equal pins — that migration is phase 2 and
is not started.

The row still carries an `ag_role` field (`Surface` / `Meeting` /
`Execution`). It is prose: what a check reads is its TARGET (§0.6a) and
nothing dispatches on the field.

**The row's shape** is documented in the module. Two fields exist for
this document's sake rather than the code's: `ag_slug`, the stable name
a section cites, and `ag_doc`, the section that defines it — the bridge
§10a's pins keep honest.

**Firing** is a function of `mechanism × lang × provision`, not a table:
Static ⇒ build + probe where something is built, probe alone where
nothing is; Dynamic ⇒ probe only; the three solo-artifact cells add
`Build_lib`. The provision axis is what makes a Fetched world skip build
sites — see §6.0 for the same idea stated over dependencies.

**Fixtures** — every wired agreement ships its minimal counterexample as
data, and the layer suite executes them hermetically, ahead of any
project run. A new agreement lands WITH its fixture; a changed predict
turns the pin red. The covered set is stated in the pin itself, so the
gaps are visible rather than implied.

## A.2 — The agreement × action matrix: read it from the code

The matrix of *which agreement fires at which action* is DERIVED — the
firing functions compute it — so a table here can only be a snapshot
that goes stale. It is printed instead:

```ocaml
Canary_agreement_registry.belief_matrix  ?mechanism ?lang ?provision ()
Canary_agreement_registry.pp_belief_matrix ?mechanism ?lang ?provision ()
Canary_agreement_registry.fill_list      ?mechanism ?lang ?provision ()
```

Marks: `✓` fires here AND ships a counterexample fixture · `~` fires,
no fixture yet — **the fill list** · `⊘` the agreement is disabled or
blocked · `·` does not fire here, by the firing derivation.

The matrix is TOTAL by construction — the firing function answers for
every action — so there is no "un-answered" state, and *filling* it has
a bounded meaning: turn `~` into `✓` by attaching a counterexample to a
cell that already fires. `fill_list` returns exactly that set.

The WIDER catalogue — including the checks that have no agreement row at
all, such as the `Postcondition` families — is §0.6c; the per-artifact
reading is A.3.

## A.3 — The same belief, read per artifact

§0.6c is organised by how a check is made; this is the same set filtered
by WHICH ARTIFACT is under test. It is a summary rather than a second
catalogue — the rows live in §0.6c — and it exists because the filter
shows something neither other view does: **where an artifact is thinly
covered, and at which point in its life.**

| artifact | checked at | thinnest point |
|---|---|---|
| **source** | fetch (existence, pinned-ref freshness, repo contents) | nothing beyond existence and provenance — and that is PRINCIPLED: a source tree's API is its headers', its behaviour is its lib's (§0.6b) |
| **headers** | their own presence; as provider at `Build_binding` (c6) | consulted once, at compile time, and then dropped — the carried-oracle idea (App. D.4) is about re-reading them later |
| **lib** | fetch (identity/pin) · `Build_lib` (three solo cells) · `Install_lib` (staged parity, designed) · `Probe_lib` (nm prefix) · as provider at build and probe | **where it merely ARRIVES or is TRANSFORMED** — `Fetch` checks identity only, and `Install_lib`'s parity family is still designed. Four stages, three mechanics, and the two weakest are the two where canary did not build it |
| **binding** | fetch/pin · `Build_binding` (c1/c2/c6) · `Probe_binding` (c1–c5, c3's trace) | **`Publish`** — nothing checks what we hand back out |
| **app** | `Build_app` (marker) · `Probe_app` (c3, tiny's oracle) | nearly bare; the direct-vs-indirect differential is proposed, not built |

Read down the last column and the fill priority is not the agreement
rows at all — it is the *stages where an artifact changes hands*: fetch,
install, publish. Those are exactly the points where canary is not the
one doing the work, which is why they were easy to leave uncovered.

# Appendix C. The standing goal, and the sequence

## C.1 — Coverage status — where it lives

The living status is [`../status.md`](../status.md) (M2 step 6) and, per
project, [`../project/status_project.md`](../project/status_project.md);
this doc should not carry a second copy that drifts from them.

What belongs HERE is only the standing definition of the goal:

> Every cell of the belief space has a DEFINED result — the pre/post
> check and the expectation hold for the good AND the bad intended
> outcome, so that completeness of checking is itself checkable.

Two structural facts that make the goal reachable, and that are
properties of the design rather than of a given week:

* **the per-action pre/post family is total by construction** — one
  postcondition per action kind (`marker_of_action`), and since the
  warm-mask fix those results are SPEC-AWARE: a marker carries a
  fingerprint of the step's command and expectation, so an edit
  self-invalidates and a stale world can no longer be served as a pass;
* **the agreement matrix is total by construction** — the firing
  function answers for every action, so there is no un-answered cell and
  "filling" means turning `~` into `✓` (A.2). `fill_list` prints the
  remainder.

Everything else — which agreements are wired this week, which
mechanisms and langs have no cells yet, what the next fill is — is
status, and lives in the trackers above.

## C.2 — Sequence (each step keeps the suite green)


1. [x] **Land the producer** (2026-08-17/18): `contract_registry` rows
   for c1..c8 (invariant, reads, source, fault tags, input template,
   firing derivation) + the fixture harness + the first fills (§0.6c) +
   the matrix view (A.2). Consumers untouched — `registered_checks` and
   the per-project tables keep working; 4 pins green. Still open
   inside this step: the ssot Ag.X ↔ C1..C8 reconciliation (the Ag.8
   decision) and §8's two drifts.
2. Switch `lower_expectation_agnostic` to derive firings from the
   registry; pin the derived firings equal to the hand-written tables
   (tiny first — richest case — then z3/llvm/sqlite).
3. Delete the per-project `*_agreement_bindings`; the tiny oracle
   combinator (`expectation_of_entry`) consumes the registry.
4. Close the gaps inside the registry: c4/OCaml's Placeholder
   prediction, `symbol_orphan`'s build failure (a new id), statuses
   → all Wired.
5. Fault-tag sync (step 9) lands as `fault_tags` on the rows.


---

# Appendix D. Carried-over drafts awaiting placement

> These were written before this doc's outline existed. Each belongs to
> a section still under review, so it is parked here rather than
> inserted — pull from it when the destination section is worked
> through. Nothing in Appendix D is confirmed.

| draft                                                           | intended destination                                                                      |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| D.1 the lib's path family                                       | §5 Resolution (search/selection); its recorded-vs-resolved half now has §6.0's vocabulary |
| ~~D.2 the lib's hidden dependencies~~                           | **PLACED 2026-09-01** — folded into §6.6                                                  |
| D.3 per-mechanism lifecycles (cstubs / cext / ctypes / dynlink) | §2.4, §2.5, §2.6 — as the artifact chains those sections enumerate                        |
| D.4 the header as a carried type oracle                         | §2.3 + §2.7 (a surface-correspondence projection), with the provider-side DWARF note      |
| D.5 staged parity                                               | §7 Transformation and packaging preservation                                              |

## D.1–D.2 — The lib — symbols, paths, hidden dependencies


Symbols are the best-developed family; two others are open and
substantial.

#### D.2a Symbols (developed)

Exports vs declared API (c1), versioned symbols (c5), the soname (c4),
and the coarse `readelf -sW` shape. See §0.6c's solo-artifact
cells.

#### D.2b Paths — the biggest untouched family

Every stage of a lib's life is mediated by a path mechanism, and they
differ per platform. The inventory (to be developed WITH the user's
pre-existing study, which predates this work and should be brought in
before designing cells):

| kind                 | Linux/ELF                                                          | macOS/Mach-O                                                 | where it bites                                                             |
| -------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------ | -------------------------------------------------------------------------- |
| loader search        | `LD_LIBRARY_PATH`, `/etc/ld.so.conf`, `ldconfig` cache             | `DYLD_LIBRARY_PATH` (stripped by SIP for protected binaries) | which lib actually loads — a system copy can shadow the built one          |
| embedded search      | `DT_RPATH` / `DT_RUNPATH` (`-Wl,-rpath`, `LD_RUN_PATH`)            | `LC_RPATH` + `@rpath` / `@loader_path` / `@executable_path`  | a build-tree path baked into a staged artifact (the portability falsifier) |
| identity             | `DT_SONAME`                                                        | `LC_ID_DYLIB` / install_name                                 | what dependents record; must be the INSTALLED identity                     |
| language-side        | `CAML_LD_LIBRARY_PATH` (OCaml stublibs), `PYTHONPATH`, `OCAMLPATH` | same                                                         | the binding's own artifacts, not the C lib                                 |
| build-time discovery | `PKG_CONFIG_PATH`, `LIBRARY_PATH`, cmake prefix paths              | same                                                         | which headers/libs the BUILD picked — often not the ones we think          |
| tool lookup          | `PATH`                                                             | `PATH`                                                       | which compiler/linker/tool ran at all                                      |

Known trap classes to turn into agreements: `DT_RUNPATH` does NOT
apply to transitive dependencies (unlike `DT_RPATH`) — a lib that
works standalone can fail as a dependency; ordering/shadowing between
a system lib and a built one; `LD_LIBRARY_PATH` ignored for
setuid/setgid; macOS install_name that must be patched AFTER the move.

#### D.2c Hidden dependencies

Things `nm` on the lib does not reveal:

- **transitive `NEEDED`** — a dependency of a dependency that must be
  present at load;
- **`dlopen`'d plugins** — resolved by name at run time, invisible to
  static inspection (this is exactly what the ctypes/cffi mechanisms
  ARE, so the binding side has the same shape);
- **symbol interposition** — another loaded object providing the same
  symbol first (LD_PRELOAD, link order, a system copy);
- **weak symbols and default version resolution** — which definition
  wins when several exist.

These are the natural home for the interposition-shim RECORDER idea
(observe what is actually requested/resolved at load) — see the
§10.



## D.3 — Per-mechanism lifecycles


"The lib" above implicitly means the **C lib**. Once `lang × mechanism`
is in play, each mechanism has its OWN artifact chain and its own
agreements. This is the second group of tables; sketches, to be filled
the same way (from real bugs, up the ladder).

#### D.3a Cstubs (OCaml, `Static_c_abi`)

| stage       | artifacts                                                                    | agreements                                                                                                          |
| ----------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| build stub  | `*_stubs.c` → `.o` → `lib<pkg>_stubs.a` (+ `dll<pkg>_stubs.so` for bytecode) | the stub compiles against the header (types); the archive's undefined refs ⊆ the lib's exports                      |
| build OCaml | `.cmi/.cmx/.cmxa/.cma`                                                       | the `.mli` surface is what the package claims; module names survive dune's wrapping convention                      |
| link        | linkopts inside the `.cmxa`                                                  | the recorded `-L`/`-l` resolve OUTSIDE the build tree (the `$CAMLORIGIN/../..` trap)                                |
| install     | ocamlfind layout, `META`                                                     | `directory`/`archive(native)`/`requires` describe the real layout; `dll*_stubs.so` lands in the switch's `stublibs` |
| use         | `CAML_LD_LIBRARY_PATH`, RPATH                                                | the stub `.so` that loads is THIS package's (a stale one in the switch shadows it)                                  |

#### D.3b Cext (Python, `Static_c_abi`)

| stage   | artifacts                               | agreements                                                                                                                           |
| ------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| build   | `_native.c` → `_native.<EXT_SUFFIX>.so` | the `EXT_SUFFIX` matches the interpreter that will import it (ABI tag + version); `PyInit_<name>` exists and matches the module name |
| link    | NEEDED + RPATH of the extension         | the C lib is resolvable from the extension's own search path                                                                         |
| package | `__init__.py`, wheel metadata           | the user-facing surface is the package's, not the extension's                                                                        |
| import  | the load meeting                        | no unresolved symbol at import; the right interpreter                                                                                |

#### D.3c Ctypes / Cffi (Python, `Dynamic_ffi`)

| stage        | artifacts                         | agreements                                                                                                                                                     |
| ------------ | --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| (no build)   | pure `.py`                        | — the absence of a build stage is itself the point: no build-time falsifier exists                                                                             |
| load         | `dlopen` by name                  | the declared soname/path resolves at import                                                                                                                    |
| call         | `argtypes`/`restype` declarations | the DECLARED types match the C signatures — checkable only against the header: this is the prime consumer-side case for the carried type oracle (App. D.4) |
| failure mode | per-call resolution               | a missing symbol surfaces at FIRST CALL, not at import — so coverage of the declared API determines what is caught at all                                      |

#### D.3d Dynlink (OCaml, `Dynamic_ffi`) — not wired

`.cmxs` plugin loading; the same shape as 3c (load-time resolution, no
build-time falsifier).



## D.4 — The header as a carried type oracle (designed, 2026-08-18)


**The gap in traditional practice.** A header is consulted exactly
once — when the binding is COMPILED. After that it is dropped: using a
binding, or wrapping it indirectly, involves no header at all. That is
fine for building, but it throws away the only artifact that carries
TYPES. A compiled component (`.so`, `.cmxa`, a cext `.so`) is
type-free: `nm` yields names and nothing else. So every stage after
the compile is checked namewise even though the type information
existed a moment earlier.

**The idea** (user, 2026-08-18): let LATER actions refer back to the
header, so a compiled component can be type-checked at stages where it
alone would be untyped — *retrofitting type information onto a compiled
component*. The header stops being a build input and becomes a
**carried oracle**: declared once, inspected once (`Scan_sources` →
`inspect_typed_header.json`), then available as an input to any
downstream cell.

**Why canary can do this cheaply.** The mechanism already exists — the
typed-header JSON is emitted early (deliberately, so c6 can cite it
even when a later build fails) and it persists in the run's output
tree. What is missing is not machinery but CELLS: contracts that read
`Typed_header` at actions other than `Build_binding`.

**The chain it enables.** Types can be followed hop by hop instead of
only at the first hop:

    header (Sf.1, typed)
      → binding stub (Sf.3, typed)        ← c6 today, at build_binding
      → user-facing surface (Sf.4, typed) ← the wrapper's own claim
      → indirect wrapper / helper / app   ← nothing checks this today

Each hop must preserve the API under the declared marshalling. The last
hop is the interesting one: tiny already declares an indirect wiring
(`a_app Via_helper` beside `a_app Direct`), so the "wrapper of a
wrapper" case has a witness ready.

**Cells this yields** (all `Inspection`, all reading `Typed_header`
plus one consumer-side typed surface):

| cell                                                 | falsifier                                                                                             |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| header × user surface @ `Probe_binding`              | the user-facing signature contradicts the C signature it claims to wrap (arity, direction, ownership) |
| header × wrapper surface @ `Build_app` / `Probe_app` | an indirect wrapper re-exports the API with a changed shape                                           |
| header × consumer usage @ app stages                 | the app calls the API in a way the header's types forbid                                              |

**The provider side too — with binutils** (user, 2026-08-18). An
earlier draft called the compiled provider untypeable; that
understates the tools. `nm -D` gives names only, but the ELF file can
carry much more:

| tool / data                                          | what it yields                                                                                             | precondition                                                                                                                |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `readelf --debug-dump=info` / `objdump --dwarf=info` | **full signatures** — `DW_TAG_subprogram` with return type + formal parameter types, struct layouts, sizes | DWARF is present (`-g`, or a separate `.debug` / debuginfo package). Often absent — use it WHEN APPLICABLE, never assume it |
| `readelf -sW`                                        | symbol TYPE (FUNC/OBJECT) + size — a coarse shape check                                                    | always                                                                                                                      |
| mangled names + `c++filt`                            | parameter types encoded in the symbol itself                                                               | C++ only (C symbols carry nothing)                                                                                          |

So provider-side type retrofit is not impossible — it is
**provision-dependent**, which fits the rest of the matrix:

- **Built worlds**: canary compiles the lib itself, so canary controls
  the flags — building with `-g` GUARANTEES the oracle. The strongest
  form of the idea lands here: compare the header's declared
  signatures against the DWARF of the artifact actually produced. That
  catches header/source skew (the header claims `f(int)`, the object
  was compiled from a source where `f` takes two) — today only caught
  if some consumer compile happens to fail.
- **Fetched worlds**: distro releases are usually stripped, so the
  oracle needs the matching `-dbg`/`debuginfo` package declared as an
  extra. Where it is absent, the cell degrades to the coarse
  `readelf -sW` shape check and the meeting check (the link accepts
  the pairing or does not) — a weaker but still non-empty belief.

**Version skew — a future to-do.** Plainly: the header and the lib can
come from DIFFERENT provisions — headers from the source repo, the lib
from a package manager — and then they may not describe the same
build. A type check pairing them tests the consumer against the
SOURCE's API while the run uses the PACKAGE's lib, so a disagreement
can indict the wrong artifact. The cell must record which artifact's
version the oracle came from; blame then follows §10's direction rule.
Not designed further yet — a future to-do.



## D.5 — staged parity

Lives in its own doc, [`staged_parity.md`](staged_parity.md): the
build→install transform's divergence classes (identity transforms,
content selection, missing rules, relocation failure, platform
invariants, accumulation/isolation) and the four checks
(completeness / integrity / parity / isolation), including the
portability falsifier — a staged binary must contain no concrete
build-tree path. It is the same artifact-checking family one lifecycle
stage later, and is §7's principal input.

# The agreement catalogue

**Kind: reference, GENERATED.** The summary table, then one section per agreement with its complete record — claim, obligation, where it looks, what falsifies it, and what a pass does not establish.

Do not edit: regenerate with `make agreement-catalogue`. The fields come from the registry, so this cannot drift from the code that implements them. What it does NOT show is what actually ran — that is [`landing.md`](landing.md) and `canary checks --landing`.

Evidence paths are shown for a BUILT world. The world decides where a binding's inspection sits — a Fetched binding's is at its fetch step — so the same method reads different paths in different worlds.

The model these fields belong to is [`registry.md`](registry.md) §1; how a project reaches one is [`pipeline.md`](pipeline.md).

## What each agreement recovers

Every row is one action's rule, re-derived from what survived it. **Action** is where the rule ran — not where the check fires, which is wherever the evidence lands and is usually later. **Tool** is what applied it; **artifact** is what it ranged over.

A `code-set` action is one THIS graph contains, so the row can be read against `canary paths`. A plain-prose one is not: the link that built a consumer ran in a world this graph never modelled, and "the link" is several actions depending on who is linking. Naming those in the action type would be a lie in both directions; drawing them needs the action-unit view, which is deferred in [`registry.md`](registry.md) §7.4.4.

| code | agreement | action | tool | artifact | checked at | status |
| --- | --- | --- | --- | --- | --- | --- |
| `dse` | [`declared_symbols_exported`](#declared_symbols_exported) | `build_lib` | compiler + linker | the library's exported symbols | `build_lib_post` | evaluated |
| `smd` | [`soname_matches_declaration`](#soname_matches_declaration) | `build_lib` | linker (-Wl,-soname) | the library's SONAME record | `build_lib_post` | evaluated |
| `dve` | [`declared_versions_exported`](#declared_versions_exported) | `build_lib` | linker (version script) | the library's symbol-version nodes | `build_lib_post` | evaluated |
| `sip` | [`staged_interface_preserved`](#staged_interface_preserved) | `install_lib` | the install tool | the staged copy of the library | `install_lib_post` | evaluated |
| `rse` | [`required_symbols_exported`](#required_symbols_exported) | `build_binding_ocaml` | linker | the stub archive's undefined references. The link that made them ran in whatever world built the consumer, which this graph need not contain — so where the binding is fetched rather than built, the check falls to the probe | `build_binding_ocaml_pre → probe_binding_ocaml_pre` | evaluated |
| `smr` | [`soname_matches_requirement`](#soname_matches_requirement) | `build_binding_ocaml` | linker | the consumer's NEEDED record. The link that wrote it ran in whatever world built that consumer, which this graph need not contain | `build_binding_ocaml_pre → probe_binding_ocaml_pre` | evaluated |
| `rve` | [`required_versions_exported`](#required_versions_exported) | `build_binding_ocaml` | linker | the consumer's versioned symbol references, written by the link that produced it — in whatever world that was | `build_binding_ocaml_pre → probe_binding_ocaml_pre` | evaluated |
| `sa` | [`signatures_agree`](#signatures_agree) | `build_binding_ocaml` | the C compiler | the stub's calls against the header's declarations | `build_binding_ocaml_pre → probe_binding_ocaml_pre` | evaluated |
| `dp` | [`dependencies_provided`](#dependencies_provided) | `probe_binding_ocaml` | linker, then the dynamic loader | the consumer's NEEDED list. The linker wrote it and the LOADER re-checks it at every load, which is why the probe is the action named here rather than the link | `build_binding_ocaml_pre → probe_binding_ocaml_pre` | evaluated |
| `anp` | [`api_names_present`](#api_names_present) | `build_app_ocaml` | the language compiler | the binding's user-facing interface. Most projects declare no app, so the rule's own action is absent and the check falls to the binding probe | `build_app_ocaml_pre → probe_binding_ocaml_pre` | evaluated |

### Rooted in no action's rule

These 3 are not checks waiting on evidence. No toolchain enforces them, so there is no relation to recover — only one to state. They are exactly the rows with no evaluator, which is what tells "nobody implemented this" apart from "nobody has said what it means".

| code | agreement | why there is no rule | status |
| --- | --- | --- | --- |
| `bm` | [`behavior_matches`](#behavior_matches) | no toolchain enforces that a function returns what a project expected — a compiler checks types, a linker checks names, and neither has an opinion about results. There is no relation here to recover, only one to STATE, which is why this is unimplemented in a different sense from an agreement that merely lacks evidence | planned |
| `rpa` | [`repack_preserves_api`](#repack_preserves_api) | a binding's two layers are both written by the author, and nothing compiles one against the other in a way that could reject a rename, a merge or a deliberate omission. This is a claim about INTENT, and it needs stating before it can be checked | planned |
| `rc` | [`repack_complete`](#repack_complete) | unrooted TWICE OVER: it composes one agreement that has a rule (the linker's) with two that do not. A composition cannot be better rooted than its weakest part | planned |

---

# The records

## declared_symbols_exported

| | |
| --- | --- |
| subject | symbols |
| claim | structural — about artifacts and their fit |
| obligation | project-declaration |
| status | evaluated |
| fault tag | sym_missing |
| doc | §2.2 |
| enabled | yes |

### Claim


**Says:** every function the project declares in c_api is exported by the built lib

**Held against:** the project's declared c_api export set; a name in the declaration that the built library does not export is the falsifier

**Recovers:** build_lib — compiler + linker, over the library's exported symbols. the compiler and linker turned declarations into definitions and exported them. The declaration this checks against is the project's rather than the header's, so it recovers a WEAKER rule than the compiler's own: it asks whether what the project said it ships is there, not whether every declaration agreed with its definition

**Checked at:** ocaml: build_lib_post; python: build_lib_post

### Method: declared_exports_vs_library

| | |
| --- | --- |
| compares | compare |
| against | declaration |
| implemented | yes |
| ocaml/cstubs@built | fires at build_lib |
|   reads | native summary build_lib/inspect.json | probe_lib/inspect.json |
| python/cext@built | fires at build_lib |
|   reads | native summary build_lib/inspect.json | probe_lib/inspect.json |
| limits | only declared names are covered; signatures, versions and behaviour are not. A name present says nothing about what it does. |

**Examples**

**1. reports `violated`** — finding: `tiny_offset`

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_diff"]}
```

**2. reports `unavailable`**

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_diff"]}
```


## required_symbols_exported

| | |
| --- | --- |
| subject | symbols |
| claim | structural — about artifacts and their fit |
| obligation | toolchain-rule |
| status | evaluated |
| fault tag | sym_missing |
| doc | §3.1.2 |
| enabled | yes |

### Claim


**Says:** every symbol the binding's stub references is exported by the lib

**Held against:** the consumer's own recorded requirements: the undefined references in its compiled stub. A required symbol the provider does not export is the falsifier, and the linker or loader would say the same

**Recovers:** build_binding_ocaml — linker, over the stub archive's undefined references. The link that made them ran in whatever world built the consumer, which this graph need not contain — so where the binding is fetched rather than built, the check falls to the probe. the linker's rule is that every referenced symbol has a definition. It ran once, when the binding was built against some library; this re-derives it, for names, against whichever library THIS world actually holds

**Checked at:** ocaml: build_binding_ocaml_pre → probe_binding_ocaml_pre; python: build_binding_python_pre → probe_binding_python_pre

### Method: stub_requirements_vs_library_exports

| | |
| --- | --- |
| compares | compare |
| against | peer |
| implemented | yes |
| ocaml/cstubs@built | fires at build_binding_ocaml, probe_binding_ocaml |
|   reads | compiled-stub summary build_binding_ocaml/inspect_stub.json | build_binding_ocaml/inspect.json |
|   reads | native summary build_lib/inspect.json | probe_lib/inspect.json |
| python/cext@built | fires at build_binding_python, probe_binding_python |
|   reads | compiled-stub summary build_binding_python/inspect_stub.json | build_binding_python/inspect.json |
|   reads | native summary build_lib/inspect.json | probe_lib/inspect.json |
| limits | set inclusion only: it does not check signatures, symbol versions, or which definition the loader will actually bind. Inclusion over a very small requirement set may also mean the binding is stale rather than deliberately narrow. |

**Examples**

**1. reports `violated`** — finding: `tiny_offset`

`stub.json`:

```json
{"kind": "c_stub", "path": "fx",
    "requires": ["tiny_sum", "tiny_offset"]}
```

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_diff"]}
```

**2. reports `holds`**

`stub.json`:

```json
{"kind": "c_stub", "path": "fx",
    "requires": ["tiny_sum", "tiny_diff"]}
```

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_diff"]}
```

**3. reports `unavailable`**

`stub.json`:

```json
{"kind": "c_stub", "path": "fx",
    "requires": ["tiny_sum"]}
```


## api_names_present

| | |
| --- | --- |
| subject | api-names |
| claim | structural — about artifacts and their fit |
| obligation | project-declaration |
| status | evaluated |
| fault tag | api_drop |
| doc | §3.1.1 |
| enabled | yes |

### Claim


**Says:** every watchlisted name is present on the binding's user-facing surface

**Held against:** the project's watchlist for this binding; a watched name absent from the inspected surface is the falsifier. An empty watchlist asks nothing and is reported as inconclusive, never as a pass

**Recovers:** build_app_ocaml — the language compiler, over the binding's user-facing interface. Most projects declare no app, so the rule's own action is absent and the check falls to the binding probe. the compiler's rule is that every name a consumer uses resolves on the interface it compiles against. The watchlist stands in for the application's actual uses, which makes this a hand-written APPROXIMATION of a real rule rather than a derivation of it

**Checked at:** ocaml: build_app_ocaml_pre → probe_binding_ocaml_pre; python: build_app_python_pre → probe_binding_python_pre

### Method: watchlist_vs_user_surface

| | |
| --- | --- |
| compares | inspect |
| against | declaration |
| implemented | yes |
| ocaml/cstubs@built | fires at build_binding_ocaml, probe_binding_ocaml |
|   reads | OCaml surface build_binding_ocaml/inspect.json | build_binding_ocaml/inspect_mli.json |
| python/cext@built | fires at build_binding_python, probe_binding_python |
|   reads | Python surface build_binding_python/inspect.json | build_binding_python/inspect_attrs.json |
| limits | coverage is bounded by the watchlist: names outside it are not checked, and a name being present says nothing about the signature or behaviour behind it. Obtaining the Python surface already imports the module. |

**Examples**

**1. reports `violated`** — finding: `Llvm.Opcode.UncondBr`, `Opcode.UncondBr`, `UncondBr`

`mli.json`:

```json
{"kind": "ocaml_mli", "path": "fx",
    "watchlist": {"present": [], "missing": ["Llvm.Opcode.UncondBr"]}}
```

**2. reports `violated`** — finding: `Solver.add`, `add`, `BitVec`

`py.json`:

```json
{"kind": "python", "path": "fx",
    "watchlist": {"present": [], "missing": ["Solver.add", "BitVec"]}}
```

**3. reports `inconclusive`**

`empty.json`:

```json
{"kind": "ocaml_mli", "path": "fx",
    "watchlist": {"present": [], "missing": []}}
```


## behavior_matches

| | |
| --- | --- |
| subject | behavior |
| claim | behavioral — about what running it does |
| obligation | behavioral-spec |
| status | planned |
| fault tag | behavior |
| doc | §6.3.2 |
| enabled | yes |

### Claim


**Says:** the probe's trace matches what was recorded for it

**Held against:** the probe's own embedded assertions. There is no project-independent statement of what a binding should compute, so the expectation is whatever the probe asserts — which bounds this agreement to the inputs that probe exercises

**Recovers:** NO ACTION'S RULE. no toolchain enforces that a function returns what a project expected — a compiler checks types, a linker checks names, and neither has an opinion about results. There is no relation here to recover, only one to STATE, which is why this is unimplemented in a different sense from an agreement that merely lacks evidence

**Checked at:** ocaml: probe_binding_ocaml_post; python: probe_binding_python_post

### Method: probe_assertions

| | |
| --- | --- |
| compares | run-program |
| against | declaration |
| implemented | no — planned |
| why not | the expected values live inside the probe's source as embedded assertions, and the observation is the probe's own exit code; the registry has no evaluator that could read them. Wiring one means giving the project a place to state expected results outside the probe |
| ocaml/cstubs@built | fires at probe_binding_ocaml |
| python/cext@built | fires at probe_binding_python |
| limits | not evaluated here. The probe's assertions cover the inputs that probe runs and nothing else. |
| counterexamples | none — nothing shows it can fail |

## soname_matches_declaration

| | |
| --- | --- |
| subject | identity |
| claim | structural — about artifacts and their fit |
| obligation | project-declaration |
| status | evaluated |
| fault tag | abi_soname |
| doc | §2.2 |
| enabled | yes |

### Claim


**Says:** the built lib's recorded identity is the soname the project declared

**Held against:** the project's declared soname. The linker's -Wl,-soname application is the black box; the artifact's own record is the evidence

**Recovers:** build_lib — linker (-Wl,-soname), over the library's SONAME record. the -soname flag is the only thing that puts an identity into the object. The linker is a black box here: it either recorded what was asked for or it did not, and the artifact is the evidence

**Checked at:** ocaml: build_lib_post; python: build_lib_post

### Method: declared_soname_vs_library

| | |
| --- | --- |
| compares | compare |
| against | declaration |
| implemented | yes |
| ocaml/cstubs@built | fires at build_lib |
|   reads | native summary build_lib/inspect.json | probe_lib/inspect.json |
| python/cext@built | fires at build_lib |
|   reads | native summary build_lib/inspect.json | probe_lib/inspect.json |
| limits | matching a name does not identify a unique implementation: two objects can advertise one soname and mean different things (the ncurses case). |

**Examples**

**1. reports `violated`** — finding: `soname libtiny.so.2 != declared libtiny.so.1`

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum"],
    "elf": {"soname": "libtiny.so.2", "needed": []}}
```

**2. reports `unavailable`**

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "elf": {"soname": "libtiny.so.1", "needed": []}}
```


## soname_matches_requirement

| | |
| --- | --- |
| subject | identity |
| claim | structural — about artifacts and their fit |
| obligation | toolchain-rule |
| status | evaluated |
| fault tag | abi_soname |
| doc | §4.1 |
| enabled | yes |

### Claim


**Says:** the lib's soname is the one the consumer recorded it needs

**Held against:** the consumer's own recorded dependency list. A provider advertising a name the consumer never recorded will not be selected for it

**Recovers:** build_binding_ocaml — linker, over the consumer's NEEDED record. The link that wrote it ran in whatever world built that consumer, which this graph need not contain. the linker's rule is that a recorded dependency names something it resolved against. It ran in whatever world built that consumer; this asks whether the name it wrote down is the one THIS world's provider answers to

**Checked at:** ocaml: build_binding_ocaml_pre → probe_binding_ocaml_pre; python: build_binding_python_pre → probe_binding_python_pre

### Method: library_identity_vs_consumer_record

| | |
| --- | --- |
| compares | compare |
| against | peer |
| implemented | yes |
| ocaml/cstubs@built | fires at build_binding_ocaml, probe_binding_ocaml |
|   reads | native summary build_lib/inspect.json | probe_lib/inspect.json |
|   reads | consumer identity + NEEDED probe_binding_ocaml/inspect_abi.json | build_binding_ocaml/inspect.json |
| python/cext@built | fires at build_binding_python, probe_binding_python |
|   reads | native summary build_lib/inspect.json | probe_lib/inspect.json |
|   reads | consumer identity + NEEDED probe_binding_python/inspect_abi.json | build_binding_python/inspect.json |
| limits | name equality only. It does not establish which object the loader will select, nor that the selected object means the same thing as the one linked against. |

**Examples**

**1. reports `violated`** — finding: `libtiny.so.1`

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "elf": {"soname": "libtiny.so.2", "needed": []}}
```

`consumer.json`:

```json
{"kind": "native", "path": "fx",
    "elf": {"soname": null, "needed": ["libtiny.so.1", "libc.so.6"]}}
```


## declared_versions_exported

| | |
| --- | --- |
| subject | symbol-versions |
| claim | structural — about artifacts and their fit |
| obligation | project-declaration |
| status | evaluated |
| fault tag | sym_version |
| doc | §2.2 |
| enabled | yes |

### Claim


**Says:** every version tag the project declares appears among the built lib's versioned exports

**Held against:** the project's declared version-script tags. The version script's application is the black box; the artifact's export annotations are the evidence

**Recovers:** build_lib — linker (version script), over the library's symbol-version nodes. a version script is what attaches version nodes to exported symbols. As with the soname, the tool is a black box and the annotations it wrote are the evidence

**Checked at:** ocaml: build_lib_post; python: build_lib_post

### Method: declared_tags_vs_library_exports

| | |
| --- | --- |
| compares | compare |
| against | declaration |
| implemented | yes |
| ocaml/cstubs@built | fires at build_lib |
|   reads | provider version tags build_lib/inspect.json | probe_lib/inspect.json |
| python/cext@built | fires at build_lib |
|   reads | provider version tags build_lib/inspect.json | probe_lib/inspect.json |
| limits | presence of a tag says nothing about the symbols inside it, nor about compatibility beyond the declared tags. |

**Examples**

**1. reports `violated`** — finding: `version TINY_2.0 not exported`

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "versioned_exports": {"tiny_sum": "TINY_1.0"}}
```

**2. reports `unavailable`**

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "versioned_exports": {"tiny_sum": "TINY_1.0"}}
```


## required_versions_exported

| | |
| --- | --- |
| subject | symbol-versions |
| claim | structural — about artifacts and their fit |
| obligation | toolchain-rule |
| status | evaluated |
| fault tag | sym_version |
| doc | §4.1 |
| enabled | yes |

### Claim


**Says:** the provider exports every version node the consumer requires

**Held against:** the consumer's own recorded version requirements. A required tag the provider does not export is what the loader reports as "version `X' not found"

**Recovers:** build_binding_ocaml — linker, over the consumer's versioned symbol references, written by the link that produced it — in whatever world that was. the linker's rule is that a versioned reference binds to a version node the provider exports. The LOADER re-checks it at every load, and says so verbatim when it fails — which is why this agreement can predict its diagnostic text

**Checked at:** ocaml: build_binding_ocaml_pre → probe_binding_ocaml_pre; python: build_binding_python_pre → probe_binding_python_pre

### Method: required_tags_vs_provider_exports

| | |
| --- | --- |
| compares | compare |
| against | peer |
| implemented | yes |
| ocaml/cstubs@built | fires at build_binding_ocaml, probe_binding_ocaml |
|   reads | provider version tags build_lib/inspect.json | probe_lib/inspect.json |
|   reads | consumer version tags probe_binding_ocaml/inspect_abi.json | build_binding_ocaml/inspect.json |
| python/cext@built | fires at build_binding_python, probe_binding_python |
|   reads | provider version tags build_lib/inspect.json | probe_lib/inspect.json |
|   reads | consumer version tags probe_binding_python/inspect_abi.json | build_binding_python/inspect.json |
| limits | exact tag match, direct requirements only. It does not model version ordering, and a world without symbol versioning is inconclusive rather than compatible. |

**Examples**

**1. reports `violated`** — finding: `GLIBC_2.31`

`prov.json`:

```json
{"kind": "native", "path": "fx",
    "versioned_exports": {"malloc": "GLIBC_2.17", "memcpy": "GLIBC_2.17"}}
```

`cons.json`:

```json
{"kind": "native", "path": "fx",
    "versioned_req": {"GLIBC_2.31": 3, "GLIBC_2.17": 5}}
```

**2. reports `holds`**

`prov.json`:

```json
{"kind": "native", "path": "fx",
    "versioned_exports": {"malloc": "GLIBC_2.17", "memcpy": "GLIBC_2.17"}}
```

`ok.json`:

```json
{"kind": "native", "path": "fx",
    "versioned_req": {"GLIBC_2.17": 5}}
```

**3. reports `inconclusive`**

`prov.json`:

```json
{"kind": "native", "path": "fx",
    "versioned_exports": {"malloc": "GLIBC_2.17"}}
```

`bare.json`:

```json
{"kind": "native", "path": "fx"}
```


## signatures_agree

| | |
| --- | --- |
| subject | signatures |
| claim | structural — about artifacts and their fit |
| obligation | toolchain-rule |
| status | evaluated |
| fault tag | type_arity |
| doc | §3.1.2 |
| enabled | yes |

### Claim


**Says:** the types a stub declares agree with the header it wraps

**Held against:** the provider's header signatures, for the function names the binding also declares. A disagreeing return type or argument list is what the C compiler would reject if it saw both

**Recovers:** build_binding_ocaml — the C compiler, over the stub's calls against the header's declarations. the compiler's rule is that a call agrees with the declaration in scope. It ran when the stub was compiled against some header; this re-derives it from signature summaries, TEXTUALLY, for the names both sides mention

**Checked at:** ocaml: build_binding_ocaml_pre → probe_binding_ocaml_pre; python: build_binding_python_pre → probe_binding_python_pre

### Method: header_vs_stub_signature_summaries

| | |
| --- | --- |
| compares | compare |
| against | peer |
| implemented | yes |
| ocaml/cstubs@built | fires at build_binding_ocaml, probe_binding_ocaml |
|   reads | header signatures scan_sources/inspect_typed_header.json |
|   reads | stub signatures scan_sources/inspect_typed_binding_stub_ocaml.json |
| python/cext@built | not applicable — this mechanism declares its types as values rather than at a compiled boundary, so there are no stub signatures to read |
| limits | textual comparison of type SPELLINGS, not semantic type equivalence, representation or ownership. Names on only one side are skipped. The current extractor parses known C header declarations and supplies fixed binding signatures where their names occur in the binding source — general binding-signature extraction is the next step. |

**Examples**

**1. reports `violated`** — finding: `tiny_sum`

`hdr.json`:

```json
{"kind": "typed_header", "path": "fx",
    "functions": {"tiny_sum": {"return": "int", "args": ["int", "int"]}}}
```

`stub.json`:

```json
{"kind": "typed_stub_ocaml", "path": "fx",
    "functions": {"tiny_sum": {"return": "int", "args": ["int"]}}}
```

**2. reports `holds`**

`hdr.json`:

```json
{"kind": "typed_header", "path": "fx",
    "functions": {"tiny_sum": {"return": "int", "args": ["int", "int"]}}}
```

`agree.json`:

```json
{"kind": "typed_stub_ocaml", "path": "fx",
    "functions": {"tiny_sum": {"return": "int", "args": ["int", "int"]}}}
```


## dependencies_provided

| | |
| --- | --- |
| subject | dependencies |
| claim | structural — about artifacts and their fit |
| obligation | toolchain-rule |
| status | evaluated |
| fault tag | needed_unprovided |
| doc | §5.6 |
| enabled | yes |

### Claim


**Says:** every library name the consumer records as NEEDED has a provider in this world

**Held against:** this world's modeled provider plus the family's fixed ambient-runtime list. A recorded name answered by neither is the falsifier — which is what a consumer linked where an implementation was split out, and deployed where it is folded in, produces

**Recovers:** probe_binding_ocaml — linker, then the dynamic loader, over the consumer's NEEDED list. The linker wrote it and the LOADER re-checks it at every load, which is why the probe is the action named here rather than the link. the linker recorded a set of dependency names, and the loader's rule is that each resolves to an object. This recovers the LOADER'S rule statically, for the names recorded, against the providers this world models

**Checked at:** ocaml: build_binding_ocaml_pre → probe_binding_ocaml_pre; python: build_binding_python_pre → probe_binding_python_pre

### Method: recorded_dependencies_vs_world_providers

| | |
| --- | --- |
| compares | compare |
| against | peer |
| implemented | yes |
| ocaml/cstubs@built | fires at build_binding_ocaml, probe_binding_ocaml |
|   reads | native summary build_lib/inspect.json | probe_lib/inspect.json |
|   reads | consumer identity + NEEDED probe_binding_ocaml/inspect_abi.json | build_binding_ocaml/inspect.json |
| python/cext@built | fires at build_binding_python, probe_binding_python |
|   reads | native summary build_lib/inspect.json | probe_lib/inspect.json |
|   reads | consumer identity + NEEDED probe_binding_python/inspect_abi.json | build_binding_python/inspect.json |
| limits | ONE modeled provider, direct dependencies only, and an ambient list that is code rather than a per-world policy. It does not enumerate every provider, traverse transitive dependencies, verify the ambient libraries exist, or run a loader — so a name supplied by a second unmodeled library is reported unprovided. |

**Examples**

**1. reports `violated`** — finding: `libtinfo.so.6`

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "elf": {"soname": "libncursesw.so.6", "needed": []}}
```

`consumer.json`:

```json
{"kind": "native", "path": "fx",
    "elf": {"soname": null,
            "needed": ["libncursesw.so.6", "libtinfo.so.6", "libc.so.6"]}}
```


## staged_interface_preserved

| | |
| --- | --- |
| subject | staging |
| claim | structural — about artifacts and their fit |
| obligation | toolchain-rule |
| status | evaluated |
| fault tag | staged_drift |
| doc | §6.1 |
| enabled | yes |

### Claim


**Says:** the staged library presents the same interface as the build tree's

**Held against:** the build-tree copy of the same library, which is still present. A relocation is allowed to move files and rewrite embedded paths; it is not allowed to change what the object exports, what it calls itself, or what it depends on

**Recovers:** install_lib — the install tool, over the staged copy of the library. the install tool's rule is that staging relocates without altering the interface. Unusually, it can be checked almost as strongly as it was applied: both copies are still on disk, so nothing had to be inferred from a projection

**Checked at:** ocaml: install_lib_post; python: install_lib_post

### Method: staged_vs_build_tree_summary

| | |
| --- | --- |
| compares | compare |
| against | peer |
| implemented | yes |
| ocaml/cstubs@built | does not fire |
| python/cext@built | does not fire |
| limits | it compares the summary fields an inspector records — export count, recorded identity, dependencies, embedded search paths. It does not compare the exported NAMES one by one, the contents of the objects, or any file other than the library itself, so a staging that drops a header or a data file passes. |

**Examples**

**1. reports `violated`** — finding: `soname libtiny.so.1→libtiny.so.2`

`bt.json`:

```json
{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}
```

`st.json`:

```json
{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.2", "needed": ["libc.so.6"]}}
```

**2. reports `violated`** — finding: `symbols 12→9`

`bt.json`:

```json
{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}
```

`thin.json`:

```json
{"kind": "native", "path": "fx", "counts": {"total": 9},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}
```

**3. reports `holds`**

`bt.json`:

```json
{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}
```

`same.json`:

```json
{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}
```

**4. reports `unavailable`**

`bt.json`:

```json
{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": []}}
```


## repack_preserves_api

| | |
| --- | --- |
| subject | repacking |
| claim | behavioral — about what running it does |
| obligation | behavioral-spec |
| status | planned |
| fault tag | api_repack |
| doc | §6.3.1 |
| enabled | yes |

### Claim


**Says:** the user-facing layer is a sound repacking of the stub-facing one

**Held against:** an explicit statement of which transformations a wrapper may make. Until the project supplies one, there is no reference to compare against: a wrapper may rename, combine, restrict or extend, and none of those is refuted by a name comparison

**Recovers:** NO ACTION'S RULE. a binding's two layers are both written by the author, and nothing compiles one against the other in a way that could reject a rename, a merge or a deliberate omission. This is a claim about INTENT, and it needs stating before it can be checked

**Checked at:** ocaml: build_binding_ocaml_post → probe_binding_ocaml_post; python: build_binding_python_post → probe_binding_python_post

### Method: declared_repacking_relation

| | |
| --- | --- |
| compares | run-program |
| against | declaration |
| implemented | no — planned |
| why not | the repacking relation is not specified: "preserves" has no agreed scope, so there is nothing to compare a binding against. check_api_repack compares names and declared renames, which refutes a stub-side orphan but not a wrapper whose implementation drifted; the probe's own assertions carry that case today |
| ocaml/cstubs@built | fires at probe_binding_ocaml |
| python/cext@built | fires at probe_binding_python |
| limits | not evaluated. The name-based helper, when it is connected, will refute orphaned externals only. |
| counterexamples | none — nothing shows it can fail |

## repack_complete

| | |
| --- | --- |
| subject | repacking |
| claim | behavioral — about what running it does |
| obligation | behavioral-spec |
| status | planned |
| fault tag | api_add |
| doc | §6.3.1 |
| enabled | yes |

### Claim


**Says:** the repack loses nothing the original had

**Held against:** a statement of what the binding is allowed to omit. Without one there is no reference: a binding that deliberately wraps a subset is indistinguishable from one that dropped something

**Recovers:** NO ACTION'S RULE. unrooted TWICE OVER: it composes one agreement that has a rule (the linker's) with two that do not. A composition cannot be better rooted than its weakest part

**Checked at:** ocaml: build_binding_ocaml_post → probe_binding_ocaml_post; python: build_binding_python_post → probe_binding_python_post

### Method: composed_faithfulness

| | |
| --- | --- |
| compares | run-program |
| against | declaration |
| implemented | no — planned |
| why not | the claim's scope is unsettled ("loses nothing" needs an allowed-omission policy), and two of the three agreements it composes — repacking and behaviour — have no evaluator either. check_api_faithfulness composes three verdicts and is ready for the day they exist |
| ocaml/cstubs@built | fires at build_binding_ocaml, probe_binding_ocaml |
| python/cext@built | fires at build_binding_python, probe_binding_python |
| limits | not evaluated. The composition function exists and is pure; what it would mean is the open decision. |
| counterexamples | none — nothing shows it can fail |

## Proposed

No family implements these yet.

### exports_accounted_for

**Claim:** every symbol the library exports on its declared surface is accounted for by the project's declaration — the CONVERSE of declared_symbols_exported, which together with it makes the pair an equality rather than an inclusion

**Needs:** nothing new: both sides are already in hand wherever declared_symbols_exported decides. The open question is the SURFACE — a library exports internals a declaration should not have to name, so the claim needs a prefix or visibility filter before it stops being noise

### package_contains_declared_files

**Claim:** the staged package contains every file the recipe said it installs — and the consumer's side of it: what the prefix holds is what a consumer reading the prefix will find

**Needs:** a manifest of what the install actually staged, recorded as evidence. z3 asserts exactly this today with a hand-listed `assert_staged` and two shell guards, and declares the pre-#10549 failure as two hand-written substrings; all four retire when the claim has a row

### source_is_declared_ref

**Claim:** the source tree a build read is the ref the project declared — an IDENTITY claim, so unlike the relation ones it closes exactly rather than converging

**Needs:** the resolved commit RECORDED after the fetch. The check itself already runs as a shell assertion in a check_post, which is precisely why it has no row: there is no evidence file to read

### build_tree_configured_for_source

**Claim:** the build tree was configured for THIS source tree and these options — a warm tree configured from another ref answers every later question about the wrong world

**Needs:** an inspector over the configure cache (CMakeCache.txt, config.status, dune's env) reducing it to the source path, the ref and the option set

### signatures_match_debug_info

**Claim:** the signatures the header declares are the ones the compiled library was built with — the strongest available answer to the type question, since it reads what the compiler recorded rather than what the header says now

**Needs:** a DWARF inspector and libraries built with -g. Strictly stronger than signatures_agree, which compares two TEXTS and cannot see a changed struct layout behind an unchanged spelling

### denotation_stable_across_worlds

**Claim:** a recorded library identity denotes the SAME implementation in the deploy world as in the build world

**Needs:** retain corresponding build/deploy evidence across worlds and define an observable denotation criterion (§5.5.1)

### no_duplicate_implementation

**Claim:** the resolved set contains no two identities that are one implementation (alternative spelling), and none that statically absorbs another (containment)

**Needs:** the shipped objects' evidence plus an identity/containment policy; symbol overlap alone is a discovery heuristic (§5.5.3)

### interposition_binds_build_target

**Claim:** the definition that wins for a shared symbol is the one the consumer was built against

**Needs:** a resolved binding trace and an expected-target policy; the recorder supplies evidence, the comparison a verdict (§5.6)


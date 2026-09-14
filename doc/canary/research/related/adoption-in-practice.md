## Adoption in Practice: Mature Local Tooling, Weak Compositional Checking

The existence of a tool or research prototype does not imply that its checks are routinely applied to real language bindings. The practical related work exhibits a striking adoption asymmetry: **package-management, binary-packaging, rebuild, and ABI tooling has achieved substantial production adoption, while deeper cross-language FFI analyses and cross-ecosystem composition tools remain specialized, emerging, or largely research prototypes.**

This distinction helps explain why mature Python and OCaml bindings can continue to exhibit deployment-specific failures despite extensive tooling around them.

### Adoption levels

The tools surveyed above can be divided roughly into four adoption classes:

| Tool / work                          | Approximate adoption                 | Practical role                                                               |
| ------------------------------------ | ------------------------------------ | ---------------------------------------------------------------------------- |
| `auditwheel` / manylinux             | **Production infrastructure**        | Standard Linux binary-wheel auditing and repair                              |
| `cibuildwheel`                       | **Production infrastructure**        | Multi-platform Python wheel build/test automation                            |
| opam `depexts`                       | **Core ecosystem infrastructure**    | Standard opam → system-package-manager bridge                                |
| conda-forge migrators                | **Core ecosystem infrastructure**    | Automated ABI-transition and downstream rebuild machinery                    |
| Debian/Ubuntu rebuild and package QA | **Production infrastructure**        | Archive-level install/build/test validation                                  |
| Fedora `rpminspect`                  | **Production distribution QA**       | RPM build comparison with artifact-level inspections                         |
| Libabigail / `abidiff`               | **Mature specialist infrastructure** | ABI differencing, integrated into downstream QA systems                      |
| `abi3audit`                          | **Real but specialized tool**        | Validation of Python Stable ABI packaging claims                             |
| `abicheck`                           | **Emerging tool**                    | Broad artifact/consumer ABI checking; too new for established adoption       |
| PEP 725 / PEP 804                    | **Emerging standards**               | Standardization of Python external dependencies and cross-ecosystem mappings |
| HyperRes                             | **Research system**                  | Cross-ecosystem dependency-resolution model                                  |
| Package Calculus                     | **Research/formal artifact**         | Formal semantics of package-manager resolution                               |
| Jinn                                 | **Research prototype**               | Generated dynamic checks for JNI and Python/C FFI rules                      |
| TurboJet                             | **Research prototype**               | JNI exception analysis, including an Eclipse plug-in prototype               |
| FFIChecker                           | **Research prototype**               | Rust/C cross-language memory-management checking                             |

These labels describe deployment rather than technical quality or conceptual importance.

---

### Production adoption is strongest where an ecosystem controls the whole workflow

#### `auditwheel` and the manylinux ecosystem

`auditwheel` is an example of a checker that has crossed the boundary from research-style analysis into normal packaging infrastructure. It audits Linux wheels for external shared-library dependencies and versioned symbols and can repair wheels by grafting required libraries and rewriting runtime paths. It is maintained under PyPA and explicitly implements the compatibility policies associated with the manylinux platform tags.

Its practical role is reinforced by tools such as `cibuildwheel`. `cibuildwheel` builds Linux wheels inside manylinux or musllinux containers and supports standard CI services, including GitHub Actions and other major CI systems. Its normal configuration also supports installing and testing the newly constructed wheels.

This is therefore a mature version of:

$$
\text{platform matrix}
\rightarrow
\text{build}
\rightarrow
\text{artifact inspection}
\rightarrow
\text{test}.
$$

However, its success also illustrates a different strategy from Canary. manylinux deliberately **reduces environmental variation** by constructing a normalized build environment and encouraging bundling of non-policy libraries. Canary is interested in cases where heterogeneous provisioning remains visible and where different providers may legitimately coexist.

`auditwheel` also documents an important limitation: libraries discovered through `ctypes`, `cffi`, or explicit `dlopen` are not visible through ordinary `DT_NEEDED` inspection and can therefore escape its dependency analysis. This is exactly the kind of boundary at which a language-binding-aware checker may need additional evidence.

---

#### opam `depexts`

External dependency handling is no longer an optional side mechanism in modern opam. Since opam 2.1, `depext` functionality is integrated into the package manager: opam checks external dependencies during a normal operation and can invoke the host system package manager to install them.

The current package format consequently treats `depexts` as a normal package field describing dependencies outside the opam ecosystem; opam maps them to system-managed packages according to the host platform.

Thus this interaction is already production practice:

```text
opam dependency resolution
        |
        v
external dependency declaration
        |
        v
apt / dnf / brew / other system PM
```

The remaining weakness is not lack of adoption. It is the **semantic narrowness of the interface**. A system-package identifier provides much less information than the complete native contract assumed by a binding.

For example:

```text
depext:
    libfoo-dev
```

does not necessarily encode:

```text
required header/API range
required ABI range
required compile-time features
required representation assumptions
runtime provider correspondence
```

This makes opam's very successful adoption of `depexts` positive evidence for the Canary problem: the cross-package-manager edge is heavily exercised in practice while carrying relatively weak compatibility information.

---

#### conda-forge migrations

conda-forge demonstrates that ecosystem-scale native ABI management can also achieve high automation.

When a globally pinned ABI dependency changes, migrators construct the affected dependency graph and automatically issue rebuild pull requests to downstream feedstocks. Current conda-forge documentation explicitly describes this process and notes that linked packages are rebuilt when ABI pins are updated.

This is much stronger prior art than a simple build matrix:

$$
\text{ABI transition}
\rightarrow
\text{dependency graph}
\rightarrow
\text{downstream rebuild campaign}.
$$

The distinction again lies in the unit of control. conda-forge works hard to maintain a coherent **conda-forge world**. Canary is concerned with worlds constructed by components that may have different owners:

```text
opam package
+ apt native dependency
+ pkg-config
+ local compiler
+ conda-visible runtime library
```

No single ecosystem necessarily controls that composition.

---

#### Libabigail and Fedora `rpminspect`

Libabigail is a useful case where direct end-user visibility understates adoption.

Fedora currently ships Libabigail and even a Fedora-specific `fedabipkgdiff` utility for comparing package ABIs using Fedora build-system artifacts.

More importantly, Fedora's `rpminspect` directly treats `abidiff` as one of its runtime inspection tools and documents Libabigail as the provider of that functionality.

Thus `abidiff` should be classified as a **mature specialist component embedded in larger QA pipelines**, even if application developers rarely invoke it manually.

This is important when evaluating adoption: GitHub popularity is a poor proxy for infrastructure software. A checker may have few direct users while still affecting large package populations indirectly.

---

### Specialized checkers have real use but are not universal gates

#### `abi3audit`

`abi3audit` occupies an intermediate position.

It is maintained under PyPA and directly scans Python packages for violations of their claimed `abi3` compatibility. Its public repository currently shows a modest but nontrivial developer audience, with roughly one hundred GitHub stars and active package-oriented tooling.

The significance of `abi3audit` is less its absolute user count than the workflow it demonstrates:

$$
\text{packaging claim}
\rightarrow
\text{binary evidence}
\rightarrow
\text{claim validation}.
$$

Yet this validation is not universally enforced by pip or PyPI. A project or CI pipeline must choose to run it.

This gives a useful intermediate adoption pattern for Canary: **specialized agreement checkers can exist and be useful without becoming mandatory package-manager infrastructure.**

A modular Canary architecture should therefore be able to compose such optional checkers rather than assume that every ecosystem will incorporate them directly.

---

### Emerging tools and standards show active recognition of the gap

#### `abicheck`

`abicheck` deserves strong technical consideration but cautious claims about adoption.

The current PyPI release, version 0.5.0, was uploaded on **July 16, 2026**. Its functionality is unusually close to Canary's artifact-checking layer, including packaged inputs and consumer-relative ABI analysis.

However, the project is simply too new to treat as established ecosystem infrastructure. In the sources examined for this survey, we did not find evidence comparable to Libabigail's Fedora integration, `auditwheel`'s PyPA/manylinux role, or conda-forge's migration infrastructure.

The appropriate characterization is therefore:

> **high technical overlap, emerging practical adoption.**

This distinction matters. Novelty must account for what `abicheck` can already do regardless of its user count, while the persistence of real-world binding failures depends partly on whether such checks are actually deployed.

---

#### PEP 725 and PEP 804

Python's ongoing external-dependency work is perhaps the clearest evidence that cross-package-manager composition remains unresolved in mainstream tooling.

PEP 804 is still a **Draft** Standards Track PEP as of September 2026. It proposes a registry and mapping mechanism translating generic external dependency identifiers into packages in target ecosystems. The proposal explicitly allows users to prefer providers such as conda, Homebrew, Spack, or apt and includes a reference CLI/API.

PEP 725 provides the corresponding metadata for expressing external dependencies from Python projects. Its design discussion explicitly recognizes that a dependency may be available from multiple providers, including the system or PyPI.

This is significant because Python packaging is only now standardizing:

$$
\text{logical external dependency}
\rightarrow
\text{target ecosystem package}.
$$

Canary's intended question begins one stage later:

$$
\text{mapped and installed package}
\rightarrow
\text{does the concrete artifact satisfy the binding's assumptions?}
$$

The standards work therefore strengthens rather than eliminates the practical motivation.

---

### Cross-language semantic analyses remain largely research tools

A different adoption pattern appears for deeper FFI correctness.

#### Jinn

Jinn demonstrated in PLDI 2010 that large families of JNI and Python/C rules could be represented by compact state machines and synthesized into dynamic analyses. It produced concrete bug-detection tools and operated transparently on unmodified applications and VMs.

Conceptually, this is highly relevant to an agreement-based view of binding correctness.

Yet Jinn did not become a standard Python or JVM package/build check. Its continuing visibility is primarily through the research literature rather than mainstream packaging infrastructure.

Thus Jinn represents:

> **strong conceptual prior art, weak evidence of long-term production deployment.**

#### TurboJet

TurboJet similarly provided a concrete static-analysis framework for exception-related JNI bugs and even implemented a user-facing Eclipse plug-in.

Again, the research system progressed beyond a toy prototype, but we found no evidence that this JNI analysis became a routine Java/Android build or packaging gate.

#### FFIChecker

FFIChecker for Rust/C remains publicly available as a research tool, but its current setup still requires a nightly Rust toolchain, `rustc-dev`, and LLVM 13.

That environment is quite different from the low-friction deployment expected of tools such as `cargo clippy`, `auditwheel`, or standard CI actions.

This supports a broader observation:

> **The closer a checker moves from binary/package properties toward language-pair-specific ownership, lifetime, exception, or runtime semantics, the weaker its ecosystem adoption tends to become.**

That is an empirical tendency rather than an absolute rule, but it is pronounced in the tools examined here.

---

### Cross-ecosystem resolution is also still primarily research-side

HyperRes is direct related work for cross-ecosystem dependency solving. It models many package-manager semantics, translates metadata between ecosystems, and demonstrates resolution across ecosystems that are currently separate.

However, its public presentation remains that of a research system/formalism rather than a widely deployed package manager. The 2025 work is described by its authors as a preprint/working paper.

The 2026 Package Calculus work is even clearer in this regard. Its official artifact is explicitly a Lean 4 **proof-script artifact with no executable to run**.

Consequently, these works substantially constrain the **conceptual novelty** of cross-ecosystem resolution, but they do not remove the practical deployment gap that Canary targets.

---

## The adoption gap

Putting these observations together reveals a useful pattern:

```text
                                        practical adoption

Package resolution                █████████████████
Package build / rebuild CI        █████████████████
Binary packaging policy           ████████████████
ABI differencing                  ███████████

Cross-PM metadata/mapping         █████
Cross-ecosystem resolution        ██

FFI semantic checking             ██
Ownership/lifetime checking       ██

Cross-ecosystem world testing
with derivation-aware blame
```

The exact bar lengths are illustrative, but the asymmetry is real.

Production ecosystems have developed strong machinery for questions such as:

```text
Can this dependency graph be solved?

Can this package be rebuilt?

Does this wheel obey the manylinux policy?

Did this RPM transition alter ABI?

Do reverse dependencies still build and test?
```

The less-developed questions are compositional:

```text
Which native header did this binding actually observe?

Which library implementation did its package manager intend?

Which provider did the build system actually select?

Which provider did the runtime eventually load?

Does the copied/generated foreign declaration match that provider?

Do the two languages agree on ownership, lifetime, exceptions,
callbacks, or representation?

Which package declaration or toolchain transition allowed an
incompatible combination to be considered valid?
```

Many real binding failures can therefore occur even when every local subsystem has behaved correctly according to its own contract.

---

## Implication for Canary

This adoption landscape suggests that Canary should be positioned around an **integration and composition gap**, rather than around the absence of individual checkers.

A useful framing is:

> **The ecosystem has widely adopted tools for local package, build, binary-policy, and ABI correctness, while deeper FFI checks remain specialized and the checks are rarely composed across the package-manager and toolchain boundaries that construct a deployed language binding.**

Canary can connect these layers:

$$
\underbrace{
\text{production package infrastructure}
}_{\text{resolver, build, CI, mapping}}
$$

$$
\downarrow
$$

$$
\boxed{
\text{world construction + derivation}
}
$$

$$
\downarrow
$$

$$
\underbrace{
\text{existing ABI / packaging / FFI checkers}
}_{\text{heterogeneous and partially adopted}}
$$

$$
\downarrow
$$

$$
\boxed{
\text{agreement-level localization and blame}
}
$$

The important contribution is therefore not that Canary invents every check. In many cases it should deliberately reuse mature tools such as Libabigail, `abi3audit`, or ecosystem-native inspections.

Its distinct role is to determine:

1. **which realistic cross-ecosystem worlds should be tested;**
2. **how each world was actually realized;**
3. **which cross-language and packaging agreements apply to that world;**
4. **which existing or new checker can falsify each agreement; and**
5. **which declaration or transition should be blamed when the agreement fails.**

This also provides a plausible explanation for the persistent empirical observation motivating the project:

> **Local correctness tooling has achieved much greater adoption than compositional correctness tooling. Mature bindings therefore continue to fail at the boundaries between languages, package managers, build systems, and runtime environments even when the individual components are well tested.**

That adoption gap is arguably a stronger practical motivation for Canary than the claim that an individual ABI or FFI checker is missing.

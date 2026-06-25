### Why surface?

*What ecosystem tools (gcc, ld, ocamlopt, pip, apt) actually check, the
implicit models each one carries, and the empirical motivation for the
syntactic/semantic split that drives the rest of the theory.*

**Surface** is the answer: a typed contract for artifacts. It models what
ecosystem tools actually consume and produce, lifted from implicit
convention to explicit structure. A surface declares, for each layer of
granularity, what an artifact provides and what it requires. The layers are
not arbitrary — they are derived from what the tools *actually* check:

**Table — Tool surfaces.** Sample of what ecosystem tools consume vs. produce; the empirical motivation for the syntactic / semantic split in §0.

| Tool          | Consumes (syntactic)   | Produces (semantic)              |
| ------------- | ---------------------- | -------------------------------- |
| `gcc`/`clang` | `.h` headers           | `.o` with undefined symbols      |
| `ld`          | `.o` undefined symbols | ELF with NEEDED, SONAME          |
| `ocamlopt`    | `.mli` interfaces      | `.cmi` digests, `.cmxa` archives |
| `pip install` | wheel metadata         | site-packages directory          |
| `apt install` | package dependencies   | filesystem paths                 |

The surface makes these relationships explicit and checkable. It is
descriptive — derived from what the tools do — not prescriptive — dictating
what they should do. This is both its strength and its limitation:

- **Strength**: the model works with real tools, today, without changing
  them. Every property in a surface is extractable by running the same
  commands (`nm`, `readelf`, `ocamlobjinfo`) that the tools themselves rely
  on.
- **Limitation**: the model inherits the gaps in those tools. If `nm`
  cannot see a symbol version, neither can we. If a linker silently ignores
  a type mismatch, our surface won't catch it.

This limitation is not a flaw in the theory — it is the theory's job to
make it visible. By formalising what tools *do* check, we also reveal what
they *don't*. The gaps between layers (Type, Behavior) are not holes in the model;
they are holes in the ecosystem, and the model pinpoints them.
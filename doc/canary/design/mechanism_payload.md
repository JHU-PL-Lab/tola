# Mechanism payload — typed binding declaration

> 2026-08-13. M2 steps 4–5 design (tentative — adjust as the code lands).
> Step 4 = the typed DECLARATION (universal); step 5 = command derivation
> (tiny only; external projects keep Raw commands — see below).
> A project declares its binding as ONE record: mechanism label + facts.
> Facts are stable (what the binding IS); analysis (watchlists, contract
> rows, probe choice) stays on canary's side, changeable.

## Principle

A project's binding declaration splits into:

- **Facts** (payload) — what the binding IS: its wrapped C API, its
  files, its build, its runtime coupling. Stable. Removing a field
  would change what the binding is. **The declaration is UNIVERSAL and
  mandatory** — every project declares its facts (that is what
  checker/contract selection reads); only the command DERIVATION is
  optional (Raw — see below).
- **Analysis** (canary's side) — what we CHECK and how: watchlist
  contents, contract firing rows, which example we probe. Changeable
  as our contracts evolve. (The S1 seam: provenance vs checking
  points — `Canary_surface`'s existing split, applied to the payload.)
- **Identity** — the mechanism name (`Ext_mechanism` on the artifact).
  Unchanged: born-safe string, scenario-dir key.

The contracts are stated against the **facts**, not against a mechanism
name: c1 needs "where the consumer's symbol references live"; c2 needs
"where the user surface lives"; c4 needs "how the runtime couples".
Any glue that supplies these facts is checkable — the mechanism name is
just the label for the facts. (An invented binding works by supplying
facts; we do not design for it concretely.)

## The declaration

```ocaml
(* WHAT the binding wraps + native facts — shared by all mechanisms *)
type c_api = {
  functions : string list;              (* tiny_sum, tiny_diff, tiny_offset *)
  enums     : string list;
}

type native_facts = {
  prefix  : string;                     (* "tiny_" — nm scoping *)
  soname  : string;                     (* "libtiny.so.1" — L4 *)
  headers : { dir : string; files : string list };   (* L2 source *)
}

(* the glue's coupling — the ONE variant point (WHAT, not HOW —
   the build recipe is a separate stage, see below) *)
type coupling =
  | Stub_archive of {                   (* cstubs: the stub .c + their .a *)
      sources : string list;            (* ocaml/tiny_stubs.c *)
      archive : string;                 (* ocaml/libtiny_stubs.a *)
    }
  | Compiled_ext of {                   (* cext: the .c + the .so *)
      source  : string;                 (* python_cext/tiny_cext/_native.c *)
      product : string;                 (* _native.cpython-*.so *)
    }
  | Dlopen of { name : string }         (* ctypes/dynlink: resolved at load *)

type binding_facts = {
  c_api        : c_api;
  native       : native_facts;
  coupling     : coupling;
  surface_path : string;                (* the user-facing FILE — a fact *)
                                        (* ocaml/tiny.mli | python_cext/tiny_cext/__init__.py *)
}

type binding_decl = {
  mechanism : Canary_mechanism.mechanism;   (* identity label *)
  facts     : binding_facts;
}
```

### tiny's three bindings, as declarations

```ocaml
(* OCaml cstubs *)
{ mechanism = Cstubs;
  facts = { c_api = { functions = ["tiny_sum"; "tiny_diff"; "tiny_offset"]; enums = [] };
            native = { prefix = "tiny_"; soname = "libtiny.so.1";
                       headers = { dir = "c/include"; files = ["tiny.h"] } };
            coupling = Stub_archive
              { sources = ["ocaml/tiny_stubs.c"];
                archive = "ocaml/libtiny_stubs.a" };
            surface_path = "ocaml/tiny.mli" } }

(* Python cext *)
{ mechanism = Cext;
  facts = { c_api = { functions = ["tiny_sum"; "tiny_diff"; "tiny_offset"]; enums = [] };
            native = { prefix = "tiny_"; soname = "libtiny.so.1";
                       headers = { dir = "c/include"; files = ["tiny.h"] } };
            coupling = Compiled_ext
              { source = "python_cext/tiny_cext/_native.c";
                product = "_native.cpython-*.so" };
            surface_path = "python_cext/tiny_cext/__init__.py" } }

(* Python ctypes *)
{ mechanism = Ctypes;
  facts = { c_api = { functions = ["tiny_sum"; "tiny_diff"; "tiny_offset"]; enums = [] };
            native = { prefix = "tiny_"; soname = "libtiny.so.1";
                       headers = { dir = "c/include"; files = ["tiny.h"] } };
            coupling = Dlopen { name = "libtiny.so.1" };
            surface_path = "python_ctypes/tiny_ctypes/__init__.py" } }
```

The c_api/native facts are shared across tiny's three bindings — a
project factor can hoist them; the declaration itself stays per-binding.

## The stages (2026-08-15)

1. **Declare** — this record: identify the mechanism + state the facts.
   Universal, obvious, mandatory — what checker/contract selection reads.
2. **Build** — a SEPARATE datatype: `Canary_binding_templates.build_recipe`
   (`Dune_targets of string list | Verify_product | Raw`). The mechanism
   model (`recipe_of_decl`) derives it from the facts (cstubs → dune-build
   the surface cmxa + stub archive; cext → the store provides the
   product); `Raw` = the project's own command (external projects —
   respected as-is, tricky commandline details bypassed). Project
   knowledge that is not mechanism-determined (tiny's factory cc recipe)
   stays with the factory.
3. **Check** — project-agnostic, artifact-type dependent; applies once
   the facts (stage 1) and the build results (stage 2) are identified.

## What the lowering derives

| Derives | From |
|---|---|
| build_binding cmd | `build_recipe` via `recipe_of_decl` (stage 2 — mechanism model; Raw = the project's own command) |
| c1 inspect inputs | `coupling` (archive/product) + `native` |
| c2 inspect input path | `surface_path` |
| c4 runtime facts | `native.soname` / `Dlopen.name` |
| coverage stages | discipline (already derived, step 3) |
| spec display prose | derived — `mi_artifact_shape` deleted |

Analysis-side declarations (unchanged, already separate):

- `watchlist` contents — c2's names (canary's choice)
- contract binding tables — split in step 2
- `probe_decl` — which example we run (project_spec setting)

## runner_spec absorption map

| Field | Determined by | Absorb? |
|---|---|---|
| `stores`, `fetch_*`, `pack_*`, `fetch_headers` | store (PM) | No |
| `scan_source`, `scan_sources_after` | project | No |
| `api_source` | declaration | **Yes — becomes the binding_decl** |
| `build_binding`, `probe_binding` | coupling + probe_decl | **Yes — templates** |
| `scan_sources` | stub/surface paths (facts) | **Yes** |
| `binding_user_facing_pkg` | surface_path | **Yes — derived** |
| `symbol_check`, `artifact_name` | mechanism / display | **Yes** |
| `check_post` defaults | mechanism (markers) | Yes — already defaulted |
| `configure`, `build_lib` | native build system | Partly — system templates; flags stay |
| `install_lib` | per build system | Yes — per-system template |
| `build_app`, `probe_app` | consumer shape | Partly — via probe_decl |
| `probe_lib` | location + project lib path | Partly — location template; path stays |
| `expectation` | contracts | Already absorbed (lowering) |
| `disabled_contracts` | policy | No |

## Template / Raw fallback / harness warning

**The uniform part is the CHECKING, not the build command** (user,
2026-08-15): no matter HOW an external project builds its artifacts,
HOW to use them and HOW we check them are relatively uniform — the
mechanism identification drives checker/contract selection. The raw
build command is respected as-is (subtle commandline issues bypassed in
the beginning, not fixed); only on our own forked fix may we modify it.

Absorb a command only when fully reusable as stub logic. Otherwise the
project declares it **Raw**, and the landing check flags it:

```
⚠ raw-override: build_binding_ocaml (libffi) — mechanism template
  exists (Stub_archive.dune), project uses a dedicated script.
```

The A9 action-variant table already carries the Primitive-vs-Raw split;
the payload absorption types the Primitive params as payload fields.

## Sequence

1. [x] Add `binding_decl`/`binding_facts`/`coupling` types — in base/
   beside the mechanism vocabulary (2026-08-14 reunion).
2. [x] Add the declaration to the project layer — mechanism name stays
   identity (tiny's three decls, 2026-08-13).
3. [x] Derive the absorbable runner_spec fields for TINY (2026-08-15):
   `Canary_binding_templates` emits tiny's build_binding /
   probe_binding / probe_lib / binding_user_facing_pkg from the decls —
   byte-equal to the former hand-written literals (pinned by
   `tiny1.binding_realization_matches_handwritten` + an actions.log
   diff on `tiny1/symbol_missing`). tiny is our own craft, so
   adjusting its commands is free.
4. [ ] Land the raw-override harness warning FIRST — the decl-vs-Raw
   divergence must be visible before any external project work.
5. [ ] Declare the FACTS for external projects (sqlite/z3/llvm) — the
   mechanism identification drives checker/contract selection (see
   above); their build commands stay Raw, respected as-is.
6. [ ] Delete `mi_artifact_shape` prose (display derives from facts).

**Deferred — NOT a to-do**: translating external projects' raw build
commands into our templates. It has good and bad parts and needs
discussion; in the beginning we respect the original command, and only
on our own forked fix may we modify it.

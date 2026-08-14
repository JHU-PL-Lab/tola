# Mechanism payload — typed binding declaration

> 2026-08-13. M2 step 4 design (tentative — adjust as the code lands).
> A project declares its binding as ONE record: mechanism label + facts.
> Facts are stable (what the binding IS); analysis (watchlists, contract
> rows, probe choice) stays on canary's side, changeable.

## Principle

A project's binding declaration splits into:

- **Facts** (payload) — what the binding IS: its wrapped C API, its
  files, its build, its runtime coupling. Stable. Removing a field
  would change what the binding is.
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

(* the glue's coupling — the ONE variant point *)
type coupling =
  | Stub_archive of {                   (* cstubs: compile .c → .a + cmxa *)
      sources : string list;            (* ocaml/tiny_stubs.c *)
      archive : string;                 (* ocaml/libtiny_stubs.a *)
      build   : Dune of { targets : string list }
    }
  | Compiled_ext of {                   (* cext: compile .c → .so *)
      source  : string;                 (* python_cext/tiny_cext/_native.c *)
      product : string;                 (* _native.cpython-*.so *)
      build   : Direct_cc of { include_dirs : string list;
                               library_dirs : string list; libs : string list }
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
                archive = "ocaml/libtiny_stubs.a";
                build = Dune { targets = ["ocaml/tiny.cmxa";
                                          "ocaml/libtiny_stubs.a"] } };
            surface_path = "ocaml/tiny.mli" } }

(* Python cext *)
{ mechanism = Cext;
  facts = { c_api = { functions = ["tiny_sum"; "tiny_diff"; "tiny_offset"]; enums = [] };
            native = { prefix = "tiny_"; soname = "libtiny.so.1";
                       headers = { dir = "c/include"; files = ["tiny.h"] } };
            coupling = Compiled_ext
              { source = "python_cext/tiny_cext/_native.c";
                product = "_native.cpython-*.so";
                build = Direct_cc { include_dirs = []; library_dirs = ["c/build"];
                                    libs = ["tiny"] } };
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

## What the lowering derives

| Derives | From |
|---|---|
| build_binding cmd | `coupling.build` |
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

Absorb a command only when fully reusable as stub logic. Otherwise the
project declares it **Raw**, and the landing check flags it:

```
⚠ raw-override: build_binding_ocaml (libffi) — mechanism template
  exists (Stub_archive.dune), project uses a dedicated script.
```

The A9 action-variant table already carries the Primitive-vs-Raw split;
the payload absorption types the Primitive params as payload fields.

## Sequence

1. Add `binding_decl`/`binding_facts`/`coupling` types — in base/ beside
   the mechanism vocabulary (2026-08-14 reunion).
2. Add the declaration to the project layer (artifact row / a
   `binding_decl` field) — mechanism name stays identity.
3. Derive the absorbable runner_spec fields from the declaration (the
   realization reads facts → emits today's command strings — no
   behavior change; pin-tested per project).
4. Migrate tiny first (three mechanisms, richest case), then
   sqlite/z3/llvm.
5. Add the raw-override harness warning; migrate or consciously declare
   each flagged Raw.
6. Delete `mi_artifact_shape` prose (display derives from facts).

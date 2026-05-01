# New project spec — auto-generation plan

**Motivation.** Adding a new canary project today requires ~100–200 lines of
hand-written `mk_script_spec` boilerplate: locator shell snippets, fetch/pack
commands, probe commands, install prefix conventions. Most of this is
mechanical derivation from a small sketch (library name, system PM package,
opam binding, source layout). This plan tracks the three-step foundation
needed to generate `script_spec` from a declaration.

Trigger: worth doing when project count reaches ~10. With 3–4 projects the
current hand-written approach is fine.

---

## Step 1 — Package locator as first-class type (#29)

Locator logic (llvm-config, pkg-config, brew --prefix) is currently embedded
as ad-hoc shell in each project's `probe_lib` command. Factor into:

```ocaml
type discovery_method =
  | Pkg_config of string          (* pkg-config --variable=libdir <name> *)
  | Llvm_config of string         (* llvm-config-N --libdir *)
  | Brew_prefix of string         (* $(brew --prefix <name>)/lib *)
  | Glob of string                (* ls /usr/lib/x86_64-linux-gnu/lib<name>.so* *)

type package_locator = {
  linux : discovery_method;
  macos : discovery_method;
}
```

`probe_lib` shell snippet becomes derivable from a `package_locator` value
rather than hand-written per project. `Pattern_a` already half-does this via
`lib_locator` — that type is the prototype.

## Step 2 — Store config type (#30)

`fetch_*` and `pack_*` slot scripts are hand-written calls to shared helpers
(`fetch_lib_cmd`, `fetch_binding_cmd`, `opam_pack_cmd`). A `store_config`
type makes the declarations explicit:

```ocaml
type store_entry =
  | Sys_fetch of system_package_spec         (* → fetch_lib slot *)
  | Lang_fetch of lang * opam_package_spec   (* → fetch_binding slot *)
  | Lang_pack  of lang * opam_spec           (* → pack_binding slot *)

type store_config = store_entry list
```

`derive_steps` generates the slot commands from `store_config` instead of
reading pre-filled closures from `script_spec`. Projects declare what stores
they have; the framework generates the commands.

## Step 3 — Auto-generated project configs (#32)

Given a project sketch plus a `package_locator` (#29) and `store_config`
(#30), generate the full `script_spec` automatically:

```ocaml
val mk_script_spec_from_sketch :
  name:string ->
  locator:package_locator ->
  stores:store_config ->
  api_source:Canary_artifact_api.t ->
  source:source_repo ->
  unit -> script_spec
```

Covers the Pattern A case (system lib + opam binding, no source build).
Source-build projects (z3, llvm) remain hand-written but could adopt
`store_config` for their fetch/pack slots.

Note: #31 (C API surface model) is also listed as a dependency of #32 in
the original backlog, but it primarily feeds the mismatch-prediction chain
(#16, #20) and is tracked separately there.

---

## Relation to existing work

- `canary_pattern_a.ml` is the current approximation: a template for the
  simple case (system lib + opam binding). Steps 1–3 generalise it.
- `lib_locator` in `canary_pattern_a.ml` is the prototype for Step 1.
- `fetch_lib_cmd` / `fetch_binding_cmd` / `opam_pack_cmd` in
  `canary_action.ml` / `canary_toolchain.ml` are the shared helpers that
  Step 2 would call under the hood.

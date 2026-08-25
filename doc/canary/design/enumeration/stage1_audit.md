Please refactor the Stage 1 project declaration model so that `provision` and `provider` are unified into a typed per-provision declaration.

The current design has:

```ocaml
artifact_row
  ~artifact
  ~universe
  ?provider
  ...
```

where:

* `universe` contains multiple `(provision * channel list)` cases for an artifact;
* `provider` is fixed once per artifact row;
* `provision_of_provider` maps the detailed provider back to a coarse provision;
* because an artifact may support `Fetched`, `Built`, and `Installed` simultaneously, the provider-derived provision is currently described as only the **baseline** provision.

This creates an abstraction mismatch. For example, a SQLite library may have:

```text
provider = Sys_pkg libsqlite3-dev
universe = Fetched, Built, Installed
```

but `Sys_pkg` meaningfully explains only the `Fetched` case. The `Built` case is produced from source, and the `Installed` case is produced from the built artifact. The documentation therefore needs the special rule that "the provider's provision is a baseline, not the whole truth."

Please remove this mismatch.

## Desired conceptual model

Treat a detailed provision as the primary Stage 1 declaration:

```text
artifact
  -> admissible provision specifications
```

Each provision specification should state both:

1. the coarse provision kind (`Fetched`, `Built`, `Installed`, `Vendored`, `Absent`);
2. the typed information needed to realize that particular provision.

A possible shape is:

```ocaml
type fetch_provider =
  | Repo of source_repo
  | Repo_axes of source_repo list
  | Sys_pkg of system_package_spec
  | Lang_pkg of
      { lang : lang
      ; pm : package_manager
      ; package : string
      ; self_contained : bool
      ; versions : version list
      }

type local_source =
  | Path of string
  | Cache of string

type provision_spec =
  | Absent
  | Fetched of fetch_provider
  | Built of build_source
  | Installed of install_source
  | Vendored of local_source
```

The exact names/types can be adjusted to fit the existing codebase. Preserve the important property that this is a **sum type**, so invalid combinations are unrepresentable.

Do not replace it with a loose record such as:

```ocaml
{ provision; provider; action; source }
```

because that would recreate illegal combinations such as `Absent + action`, `Installed + Sys_pkg`, etc.

## Keep the coarse `provision` type

Do not eliminate the existing small enum:

```ocaml
type provision =
  | Absent
  | Fetched
  | Built
  | Installed
  | Vendored
```

It remains useful for:

* scenario identity;
* matrix labels;
* ordering/comparison;
* filtering;
* directory names;
* downstream code that only cares about the coarse state.

Instead, make it a projection from the detailed declaration, analogous to `artifact_kind` being a coarse projection from `artifact_info`:

```ocaml
val provision_of_spec : provision_spec -> provision
```

Conceptually:

```text
artifact_info          provision_spec
     |                       |
     v                       v
artifact_kind             provision
```

## Move provider information into the relevant provision branch

The artifact row should no longer have one independent `provider` field.

Conceptually change:

```ocaml
artifact_row
  ~artifact
  ~universe
  ~provider
```

toward something like:

```ocaml
artifact_row
  ~artifact
  ~universe
```

where the universe contains detailed provision cases, for example:

```ocaml
type provision_case =
  { spec : provision_spec
  ; channels : channel list
  }
```

or an equivalent representation.

Thus a declaration conceptually becomes:

```text
A_lib@Fetched
    <- Sys_pkg libsqlite3-dev

A_lib@Built
    <- Build_lib(A_source)

A_lib@Installed
    <- Install_lib(A_lib@Built)
```

rather than:

```text
A_lib provider = Sys_pkg libsqlite3-dev

A_lib universe =
    Fetched
    Built
    Installed
```

The latter requires an artificial "baseline provider" interpretation; the former directly states the provenance of every admissible placement.

## Preserve and strengthen the existing arrow model

The existing design already says that an artifact comes from its provider **via an action**, and that fetching and building have the same general shape.

Carry that idea through consistently.

The unified conceptual model should be:

```text
external source   --Fetch------> artifact@Fetched
source artifact   --Build------> artifact@Built
artifact@Built    --Install----> artifact@Installed
external path     -------------> artifact@Vendored
```

This means that `provider` should become a narrower concept, primarily describing an **external fetch source**, rather than remaining a project-level property of an artifact.

`Built` and `Installed` should express their internal production source directly.

The model can eventually be understood as a provenance/production-edge model:

```text
origin -- action --> placement
```

where an origin may be external or another artifact placement. However, keep the strongly typed sum representation as the declaration-level API rather than prematurely replacing it with a generic graph-edge record.

## Versions/channels

Preserve the current important invariant that the channel/version universe is **per provision**, not just per artifact.

For example:

```text
Fetched   -> Stable
Built     -> Stable, Dev
Installed -> Stable, Dev
```

should remain expressible without generating invalid cross-products.

Detailed source information should now belong to those same provision branches.

## Derived information

Review the functions currently derived from `provider`, especially:

```text
provision_of_provider
dep_mode_of_provider
versions_of_provider
providing_action_of
```

Reassign their responsibilities under the new model.

In particular:

* `provision_of_provider` should no longer be needed as an invariant-maintenance mechanism between two independent declarations;
* the coarse provision should be projected directly from `provision_spec`;
* producing actions should be derived from the relevant provision specification;
* provider-specific runtime properties can remain projections from the nested fetch provider where appropriate;
* version/pin derivation should be moved to the most semantically appropriate level, while preserving existing behavior.

Also remove invariants/tests whose only purpose was to ensure that `provider` and baseline `provision` did not drift, replacing them with stronger type-level structure and appropriate new tests.

## Documentation

Update `stage1` documentation to reflect the new model.

In particular, remove or rewrite:

* "one provider and many provisions";
* the `provision` vs `provider` comparison based on per-placement vs per-row granularity;
* the concept that `provision_of_provider` gives only a baseline;
* warnings caused by duplicate `Absent`/`Vendored` constructors across unrelated types.

Explain instead that:

* an artifact declares a universe of admissible **provision specifications**;
* each specification describes one way that artifact can exist;
* `provision` is the coarse projection used by enumeration/scenario identity;
* detailed fetch providers are only one form of origin;
* `Built` and `Installed` describe internal production edges;
* `Vendored` describes an externally existing local artifact;
* `Absent` has no producer.

Please make the refactor end-to-end rather than adding a compatibility layer that leaves the old `provider + universe` model as the conceptual source of truth.

Run/update the relevant tests and pins, and inspect callers so that the new structure becomes the canonical Stage 1 representation.

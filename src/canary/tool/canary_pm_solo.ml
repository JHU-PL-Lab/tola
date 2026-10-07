(** THE PM-SOLO TABLE CANARY COVERS (2026-09-23, status.md §2.7; user:
    "the whole chain needs two rows (two pm) from the PM-solo table, and
    one binding table").

    One row per package manager canary drives. A chain is two of these —
    the system side and the language side — one binding mechanism
    ([Canary_mechanism]) between them, and their cooperation
    ([Canary_topology.coop_of]).

    Canary's own table, not the layered-model draft's: the draft
    (`doc/audit/multi_pm.md`, Table 1) also covers RPM, Cargo, Cabal,
    RubyGems, Conda and Nix, which canary does not drive. Its columns were
    the reference; the rows here are the four managers canary has a
    driver for. The columns follow the components: the manager (M), the
    packaging (P) and the payload (A), each cell one short term (user,
    2026-10-06). Some are READ from elsewhere rather than written here:

    - side and store: the driver's own [properties] ([Canary_pm.properties]);
    - the bridges its packaging can define: [Canary_bridge.kinds_defined];
    - what goes unrecorded inside an install: [Canary_pm_action], the
      list the placeholder steps are made from.

    The rest is what only a person can say about a package manager. *)

open Base

type row = {
  ps_pm : Canary_store.package_manager;
  ps_format : string;  (** P: what declares a package, in this manager *)
  ps_version : string;  (** P: what a package's version is *)
  ps_capability : string;
      (** P: the TERM for its capability file — what the overview writes
          under the "capability file" node while this manager is the one
          whose package ships it (user, 2026-09-24) *)
  ps_built : string;  (** A: whether the payload arrives built or is built at install *)
  ps_carries : string;  (** A: what the payload is *)
}

let table : row list =
  [ { ps_pm = Canary_store.Apt; ps_format = "control file"; ps_version = "Debian version";
      ps_capability = ".pc file"; ps_built = "prebuilt";
      ps_carries = "library; headers in the dev package" };
    { ps_pm = Canary_store.Brew; ps_format = "formula"; ps_version = "version, revision";
      ps_capability = ".pc file"; ps_built = "prebuilt bottle"; ps_carries = "library, headers" };
    { ps_pm = Canary_store.Opam; ps_format = "opam file"; ps_version = "package version";
      ps_capability = "META file"; ps_built = "at install";
      ps_carries = "modules, stub archive, .mli" };
    { ps_pm = Canary_store.Pip; ps_format = "dist-info"; ps_version = "distribution version";
      ps_capability = "dist-info metadata"; ps_built = "wheel prebuilt; sdist at install";
      ps_carries = "modules; a wheel may carry the native library" } ]

(** What the table's notes say once for every row. *)
let notes =
  [ "† out of reach: the tool reports the solution, not the search that found it; the rest \
     of that column could be recorded and is not yet.";
    "A version is the package's own: none speaks for the library's soname or symbol \
     versions, and a conf-* package's version is its own revision." ]

let row_of (pm : Canary_store.package_manager) : row option =
  List.find table ~f:(fun r -> Poly.equal r.ps_pm pm)

(** The capability-file term of a package manager, if canary has a row
    for it. *)
let capability_of (pm : Canary_store.package_manager) : string option =
  Option.map (row_of pm) ~f:(fun r -> r.ps_capability)

(** Side and store, as the driver declares them. *)
let scope_of (pm : Canary_store.package_manager) : string =
  match Canary_pm.properties pm with
  | Some { Canary_store.scope = Canary_store.System; _ } -> "system"
  | Some { Canary_store.scope = Canary_store.Lang; _ } -> "language"
  | None -> "—"

let store_of (pm : Canary_store.package_manager) : string =
  match Canary_pm.properties pm with
  | Some { Canary_store.behavior = Canary_store.Stateful_global; _ } -> "global"
  | Some { Canary_store.behavior = Canary_store.Isolated_store name; _ } -> "per " ^ name
  | Some { Canary_store.behavior = Canary_store.Stateless; _ } -> "none"
  | None -> "—"

(** The short terms of the bridges its packaging can define. *)
let bridges_of (pm : Canary_store.package_manager) : string list =
  List.map (Canary_bridge.kinds_defined pm) ~f:fst

(** What goes unrecorded inside an install of a binding, by name, an
    out-of-reach piece marked †. *)
let unrecorded_of (pm : Canary_store.package_manager) : string list =
  List.map (Canary_pm_action.inside_install pm ~of_binding:true) ~f:(fun p ->
      p.Canary_pm_action.ph_key
      ^
      match p.Canary_pm_action.ph_unseen with
      | Canary_pm_action.Out_of_reach _ -> "†"
      | Canary_pm_action.Not_yet _ -> "")

(** A row in one line, for §1's note on a chosen package manager. *)
let summary (r : row) : string =
  Printf.sprintf "%s side; packaging: %s, %s, %s; payload: %s, %s" (scope_of r.ps_pm)
    r.ps_format r.ps_version r.ps_capability r.ps_built r.ps_carries

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
    driver for, and most of each row is READ from somewhere else rather
    than written here:

    - scope and store: the driver's own [properties]
      ([Canary_pm.properties]), which had no reader until this table;
    - the bridge kinds it defines: [Canary_bridge.kinds_of_pm];
    - what goes unrecorded inside an install: [Canary_pm_action], the
      list the placeholder steps are made from.

    The three prose columns are what only a person can say about a
    package manager. *)

open Base

type row = {
  ps_pm : Canary_store.package_manager;
  ps_package : string;  (** what a package is, in this manager *)
  ps_versions : string;
      (** which version domains it has, and which it does NOT speak for *)
  ps_ships : string;
      (** what it puts beside the artifacts for others to read — the
          capability files a claim can be held to *)
}

let table : row list =
  [ { ps_pm = Canary_store.Apt;
      ps_package =
        "a built binary package; a library comes split into a runtime \
         package (libgmp10) and a development one (libgmp-dev) with the \
         headers";
      ps_versions =
        "the Debian version (2:6.3.0+dfsg-2ubuntu6.1) — not the upstream \
         version, the soname, or the symbol versions";
      ps_ships =
        "headers, the shared library, a .pc file, sometimes a CMake config \
         — the capability files a conf package's check reads" };
    { ps_pm = Canary_store.Brew;
      ps_package =
        "a formula, installed as a prebuilt bottle into its own keg under \
         the prefix, and linked into the prefix";
      ps_versions =
        "the formula version and revision — not the Mach-O install name \
         or compatibility version";
      ps_ships = "headers, the dylib, a .pc file, in the keg" };
    { ps_pm = Canary_store.Opam;
      ps_package =
        "a recipe built from source when installed — the binding and its \
         stubs are compiled on the machine, against whatever the system \
         provides";
      ps_versions =
        "the opam package version; a conf package's version is its OWN \
         revision, and names the library's only when its check enforces \
         one";
      ps_ships =
        "a META file (what findlib resolves), the compiled modules, the \
         stub archive, the installed .mli — read by the package-linked \
         consumer" };
    { ps_pm = Canary_store.Pip;
      ps_package =
        "a distribution: a wheel, prebuilt and possibly carrying the \
         native library inside it, or an sdist built on install";
      ps_versions =
        "the distribution version — unrelated to the version of a native \
         library it bundles";
      ps_ships =
        "dist-info metadata; a wheel's bundled libraries sit inside the \
         package" } ]

let row_of (pm : Canary_store.package_manager) : row option =
  List.find table ~f:(fun r -> Poly.equal r.ps_pm pm)

(** Scope and store, as the driver declares them. *)
let scope_of (pm : Canary_store.package_manager) : string =
  match Canary_pm.properties pm with
  | Some { Canary_store.scope = Canary_store.System; _ } -> "system"
  | Some { Canary_store.scope = Canary_store.Lang; _ } -> "language"
  | None -> "—"

let store_of (pm : Canary_store.package_manager) : string =
  match Canary_pm.properties pm with
  | Some p ->
      Canary_store.string_of_store_behavior p.Canary_store.behavior
      ^ " — " ^ p.Canary_store.switching
  | None -> "—"

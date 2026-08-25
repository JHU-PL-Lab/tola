(** [Canary_registry] — THE single source of truth for project names
    (2026-08-11; unified to plain [project_run]s 2026-08-12). Every command
    looks up a project here; adding a project = adding one entry.

    Lives in its own module (not [canary_project_run]) because it references
    every project module, each of which references [canary_project_run] for the
    [project_run] type — a module cycle dune rejects. The former [Multi] entry
    kind (ssl's shared-switch variant matrix via [run_project_multi]) retired
    2026-08-12: ssl migrated to the general enumeration with store pins (see
    doc/canary/project/opam_exclusive_store_issue.md). *)

(** The registry. [z3_run]/[llvm_run] ignore their distro argument (distro
    detection happens inside [realize] at run time) — [Wsl] is a placeholder.
    [tiny1/<name>] and [tiny/<name>] stay dynamic (created per scenario) and are
    handled by the bin layer, not listed here. *)
let all_projects : (string * Canary_project_run.project_run) list =
  [
    ("sqlite", Canary_project_sqlite.sqlite_run);
    (* ("z3", Canary_project_z3.z3_run Canary_store.Wsl); *)
    ("llvm", Canary_project_llvm.llvm_run Canary_store.Wsl);
    ("tiny-full", Canary_project_tiny.tiny_full_run);
    ("zarith", Canary_project_zarith.zarith_run);
    ("cairo", Canary_project_cairo.cairo_run);
    ("libffi", Canary_project_libffi.libffi_run);
    ("zlib", Canary_project_zlib.zlib_run);
    ("zstd", Canary_project_zstd.zstd_run);
    ("ssl", Canary_project_ssl.ssl_run);
  ]

(** Every project canary KNOWS, whether or not it is currently active
    (2026-08-21). [all_projects] is the ACTIVE list — entries there are
    commented in and out by hand, deliberately: a project can be muted
    when its cost outweighs what a run of it buys right now (z3's
    [fetch_binding_ocaml] rebuilds libz3 from source on every binding pin
    flip, so a full run is ~30 min — see
    doc/canary/design/enumeration/stage4_order_worlds.md §3).

    Muting must not be able to hide drift, so the catalogue exists
    separately: pins assert that the active names are a SUBSET of this
    list (an unknown name is still an error) and that every project named
    here still has a well-formed spec, active or not. What muting
    suppresses is running it, not checking it. *)
let all_specs : (string * Canary_project_run.project_run) list =
  [
    ("sqlite", Canary_project_sqlite.sqlite_run);
    ("z3", Canary_project_z3.z3_run Canary_store.Wsl);
    ("llvm", Canary_project_llvm.llvm_run Canary_store.Wsl);
    ("tiny-full", Canary_project_tiny.tiny_full_run);
    ("zarith", Canary_project_zarith.zarith_run);
    ("cairo", Canary_project_cairo.cairo_run);
    ("libffi", Canary_project_libffi.libffi_run);
    ("zlib", Canary_project_zlib.zlib_run);
    ("zstd", Canary_project_zstd.zstd_run);
    ("ssl", Canary_project_ssl.ssl_run);
  ]

let catalogue : string list = List.map fst all_specs

let is_active (name : string) : bool =
  List.mem_assoc name all_projects

(** Catalogued projects that are currently commented out of the run set. *)
let muted () : string list =
  List.filter (fun n -> not (is_active n)) catalogue

(** The declared prebuilt (Vendored) libs, per project (2026-08-19). The
    `prebuilt` command prepares these before any run; a project whose lib axis
    has one point declares none, and its spec rationale says why. *)
let declared_prebuilts () : (string * Canary_prebuilt.t) list =
  List.filter_map
    (fun (name, d) ->
      match d.Canary_opam_binding.prebuilt_latest with
      | Some pb -> Some (name, pb)
      | None -> None)
    [
      ("libffi", Canary_project_libffi.decl);
      ("cairo", Canary_project_cairo.decl);
      ("zlib", Canary_project_zlib.decl);
      ("zstd", Canary_project_zstd.decl);
      ("zarith", Canary_project_zarith.decl);
    ]

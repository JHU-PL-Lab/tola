open Base

(* ── The result table (2026-08-17, user) ──
   A cross-project verdict matrix: ROWS = project × scenario (the
   ENUMERATED worlds — a stable shape, never-run scenarios show all
   [·]), COLUMNS = actions (the union across the registry in
   catalogue order). Cells carry the last-run verdict from the shared
   actions.log (via {!Canary_status.project_matrix} — the only
   per-scenario run record). The future extension: pre/post-check
   columns ("each checks") appended to the action set.

   Rendered in the cmd (text/md/json) and as the web page
   [docs/canary/projects/matrix.html]. Pure read — no execution. *)

(** One matrix cell: the verdict mark (✓/✗/xfail[cN]/·/⊘ — the
    {!Canary_status} vocabulary) plus the PROVISION CHOICE of the
    action's primary artifact in this scenario (e.g. [B:d] = built
    @dev, [F:4.16.0] = fetched at a pinned version, [F:sys] = the
    system PM's version — the information the long scenario names
    carried, now living in the cell), plus the verdict DETAIL (the
    log event's reason — the xfail's confirmed-expected-failure text
    names the fix, a failure's postcondition message — shown in the
    cell's tooltip). The cell is [None] when the action is NOT part
    of the scenario's chain (distinct from [·] = in the chain, never
    run). *)
type cell = { mark : string; provision : string; detail : string option }

(** One SETTING cell (2026-08-19, user: "move all the provider ahead, so
    we have source ref, fetched lib and ocaml ones … more clear to
    readers on which is the setting for this row"): the placement of ONE
    declared artifact in this world — the row's WORLD, printed once per
    artifact instead of repeated inside every action cell.

    This is also the answer to "ref is not the only world": the old
    single [ref] column named a row after one coordinate, and which
    artifact that coordinate belonged to varied per project (z3's ref is
    the lib's source, zarith's is the BINDING's). A column per artifact
    says which is which, and a project with two sources gets two source
    columns. *)
type setting = {
  text : string;
      (** the placement, e.g. [F pre-10549] / [B:dev] / [apt sqlite3.3.45.1] *)
  url : string option;  (** the commit/tree link, for source artifacts *)
  title : string option;  (** hover detail (the full ref label) *)
}

type row = {
  project : string;
  scenario : string;
      (** the full scenario id — the cmd views' label and the web
          tooltip (the web replaces the long name with ref+platform) *)
  index : int;
      (** the GLOBAL row ordinal (1-based across the whole matrix, in
          the rendered row order) — fast pointing ("z3 row 4"). PURE
          DISPLAY: derived at render time, never part of any cache key
          or scenario identity. *)
  code : string;
      (** the STABLE row code — a short digest of (project, scenario):
          the "truly global" half of the row index. Unlike the ordinal
          it survives row-set changes and therefore points at a
          HISTORICAL run's row too (same row → same code, forever).
          Also pure display. *)
  ref_label : string;
      (** the source repo's ref (e.g. "pre-10549", "release-1.14" —
          the declared [ref_]; the source pin id when no repo record
          is declared) *)
  ref_url : string option;
      (** the remote link to the exact commit/tree, when the repo has
          a Git remote *)
  platform : string;
  settings : (string * setting option) list;
      (** per SETTING column (artifact label) in column order; [None] =
          the project does not declare that artifact *)
  cells : (string * cell option) list;
      (** per column tag in column order; [None] = not in the chain *)
}

type t = {
  setting_columns : string list;
      (** the leading block: one artifact label per declared artifact,
          union across the table's projects in kind order *)
  columns : string list;
  rows : row list;
}

let mark_of_run ?(run : (string * (string * string option)) list = [])
    (tag : string) : string =
  match List.Assoc.find run tag ~equal:String.equal with
  | Some (event, detail) -> Canary_status.mark event detail
  | None -> "·"

(** The verdict's DETAIL — the log event's reason line (the xfail's
    "expected failure confirmed: … predates …" names the fix; a
    failure's "postcondition failed"/command output explains it). The
    tooltip content the user asked for. *)
let detail_of_run ?(run : (string * (string * string option)) list = [])
    (tag : string) : string option =
  match List.Assoc.find run tag ~equal:String.equal with
  | Some (_, detail) -> detail
  | None -> None

(** The scenario's run verdicts keyed by tag ([] when the project has
    no actions.log or the scenario never ran). *)
let run_of_scenario ~scenario
    (runs : (string * (string * (string * string option)) list) list) :
    (string * (string * string option)) list =
  match List.Assoc.find runs scenario ~equal:String.equal with
  | Some v -> v
  | None -> []

(* ── the web row's identity: repo ref + platform (2026-08-17, user's
   web refinement) ──
   The long scenario names duplicate the action columns (the
   provision×channel encoding IS the chain). The web view replaces the
   scenario column with the information the actions DON'T show: the
   repo ref (linked to the remote commit/tree) and the platform. *)

(** The scenario's source repo record: the source artifact's provider
    ([Repo_axes]/[Repo] family), matched by the source placement's
    pinned version id — the generic read of the per-repo identity (the
    project-local [*_source_for_assignment] dispatches use the same
    data). *)
let repo_of_source (pr : Canary_project_run.project_run)
    (a : Canary_artifact.assignment) (src : Canary_artifact.artifact_info) :
    Canary_artifact_source.source_repo option =
  let src_id = (Canary_enumerate.version_of a src).Canary_basic.id in
  let repos =
    match Canary_project_run.provenance_of pr src with
    | Some (Canary_store_config.Repo r) -> [ r ]
    | Some (Canary_store_config.Repo_axes rs) -> rs
    | _ -> []
  in
  List.find repos ~f:(fun (r : Canary_artifact_source.source_repo) ->
      String.equal r.Canary_artifact_source.version.Canary_basic.id src_id)

(** The PRIMARY source's repo — the row-level [ref_label]/[ref_url]
    carrier. A project may declare several sources (a lib's and an
    off-tree binding's); each gets its own SETTING column, and this one
    stays the row's headline provenance. *)
let source_repo_of (pr : Canary_project_run.project_run)
    (a : Canary_artifact.assignment) :
    Canary_artifact_source.source_repo option =
  repo_of_source pr a Canary_artifact.a_source

(** A 7+ char all-hex ref is a commit SHA; anything else (tags,
    branches) is a tree. *)
let is_sha (ref_ : string) : bool =
  String.length ref_ >= 7
  && String.for_all ref_ ~f:(fun c ->
         Char.(c >= '0' && c <= '9') || Char.(c >= 'a' && c <= 'f'))

(** The remote link to the exact commit/tree, when the repo has a Git
    remote. The canonical URL strips a trailing [.git]. *)
let ref_url_of (r : Canary_artifact_source.source_repo) : string option =
  match r.Canary_artifact_source.remote with
  | Some (Canary_artifact_source.Git url) ->
      let base =
        Option.value
          (String.chop_suffix url ~suffix:".git")
          ~default:url
      in
      Some
        (base ^ "/" ^ (if is_sha r.Canary_artifact_source.ref_ then "commit"
                       else "tree")
        ^ "/" ^ r.Canary_artifact_source.ref_)
  | Some _ | None -> None

(** The platform label (universal today — one distro per machine; the
    macOS CI column is the future value). *)
let platform_label () : string =
  match Canary_basic.detect_distro () with
  | Canary_store.Wsl -> "wsl_ubuntu"
  | Canary_store.MacOS_local -> "macos_local"

(* ── the cell's provision choice ── *)

(** The action's PRIMARY artifact for a provision read: the one it
    PRODUCES (build/fetch/publish); a probe shows its consumer — the
    binding of its lang first (the consumer-of-interest), else the
    first. *)
let action_artifact (act : Canary_basic.action)
    (a : Canary_artifact.assignment) : Canary_artifact.artifact_info option =
  let pick (ks : Canary_basic.artifact_kind list) :
      Canary_basic.artifact_kind option =
    match ks with
    | [] -> None
    | _ -> (
        match
          List.find ks ~f:(function Canary_basic.Binding _ -> true | _ -> false)
        with
        | Some k -> Some k
        | None -> Some (List.hd_exn ks))
  in
  let kind =
    match Canary_action.produces_of_action act with
    | [] -> pick (Canary_action.consumes_of_action act)
    | ks -> pick ks
  in
  Option.bind kind ~f:(fun k ->
      let lang =
        match act with
        | Canary_basic.Build_binding l | Canary_basic.Probe_binding l
        | Canary_basic.Fetch (Canary_basic.Binding l)
        | Canary_basic.Publish (Canary_basic.Binding l) -> Some l
        | Canary_basic.Build_app { lang = l; _ }
        | Canary_basic.Probe_app { lang = l; _ } -> Some l
        | _ -> None
      in
      List.find_map a ~f:(fun (id, _) ->
          if
            Canary_basic.equal_artifact_kind
              (Canary_artifact.kind_of id)
              k
            && (match (lang, Canary_artifact.kind_of id) with
                | Some l, Canary_basic.Binding l' -> Poly.equal l l'
                | None, _ -> true
                | _ -> false)
          then Some id
          else None))

(** The artifact KIND label for a cell: which artifact the action
    operates on — [src] source, [hdr] headers, [lib], [ocaml]/[py]
    bindings, [app]. Without it two same-ref rows (the built chain vs
    the all-fetched world) read identically. *)
let kind_label (k : Canary_basic.artifact_kind) : string =
  match k with
  | Canary_basic.Source -> "src"
  | Canary_basic.Headers -> "hdr"
  | Canary_basic.Lib -> "lib"
  | Canary_basic.Binding Canary_lang.OCaml -> "ocaml"
  | Canary_basic.Binding Canary_lang.Python -> "py"
  | Canary_basic.Binding _ -> "bind"
  | Canary_basic.Binding_source Canary_lang.OCaml -> "ocaml-src"
  | Canary_basic.Binding_source Canary_lang.Python -> "py-src"
  | Canary_basic.Binding_source _ -> "bind-src"
  | Canary_basic.App -> "app"

(** The live installed version of a system package (memoized dpkg
    query — the matrix's one runtime read; "" when unknown). *)
let sys_pkg_versions : (string, string) Hashtbl.t =
  Hashtbl.create (module String)

let sys_pkg_version (pkg : string) : string =
  match Hashtbl.find sys_pkg_versions pkg with
  | Some v -> v
  | None ->
      let v =
        let ic =
          Unix.open_process_in
            (Printf.sprintf "dpkg-query -W -f='${Version}' %s 2>/dev/null" pkg)
        in
        let line = Stdlib.In_channel.input_line ic in
        ignore (Unix.close_process_in ic : Unix.process_status);
        Option.value line ~default:""
      in
      Hashtbl.set sys_pkg_versions ~key:pkg ~data:v;
      v

(** The FETCHED annotation names the PROVIDER and the version — no
    general ":sys": the language PM shows the package + the store pin
    ([opam z3.4.16.0], [pip z3-solver]), the system PM shows the
    package + its version (the declared version_tag, else the live
    dpkg query — we DO know it), a path provider shows the path's last
    directory. *)
let fetched_note (pr : Canary_project_run.project_run)
    (a : Canary_artifact.assignment) (id : Canary_artifact.artifact_info) :
    string =
  let pin =
    (Canary_enumerate.version_of a id).Canary_basic.id
  in
  (* the NAME only: a declared package may carry a parenthetical gloss
     (sqlite's python row is "sqlite3 (stdlib, pip no-op)") which is
     useful in `spec` prose but wrecks a table column. *)
  let name pkg =
    match String.substr_index pkg ~pattern:" (" with
    | Some i -> String.prefix pkg i
    | None -> pkg
  in
  match Canary_project_run.provenance_of pr id with
  | Some (Canary_store_config.Lang_pkg { pm = Canary_store.Opam; package; _ }) ->
      "opam " ^ name package ^ (if String.is_empty pin then "" else "." ^ pin)
  | Some (Canary_store_config.Lang_pkg { pm = Canary_store.Pip; package; _ }) ->
      "pip " ^ name package ^ (if String.is_empty pin then "" else "." ^ pin)
  | Some (Canary_store_config.Sys_pkg spec) ->
      let pm, pkg =
        match Canary_basic.detect_distro () with
        | Canary_store.Wsl -> ("apt", spec.Canary_store.linux_pkg)
        | Canary_store.MacOS_local -> ("brew", spec.Canary_store.macos_pkg)
      in
      let ver =
        match spec.Canary_store.version_tag with
        | Some t -> t
        | None -> sys_pkg_version pkg
      in
      (* strip the Debian packaging revision (4.8.12-3.1build1 →
         4.8.12) — the display shows the UPSTREAM version *)
      let ver =
        match String.lsplit2 ver ~on:'-' with
        | Some (up, _) -> up
        | None -> ver
      in
      pm ^ " " ^ pkg ^ (if String.is_empty ver then "" else "." ^ ver)
  | Some (Canary_store_config.Vendored path)
  | Some (Canary_store_config.Cached path) ->
      "path:" ^ Stdlib.Filename.basename path
  | _ ->
      (* no provider declared (or a repo — the source case is handled
         by the caller) *)
      "F"

(** The stage a step LEAVES its primary artifact in (2026-08-19, user).
    A staged world's lib is [Installed] for the WORLD, but its
    [Build_lib] step still produced a BUILT tree — annotating every cell
    with the world's provision made all three of build/install/probe read
    [lib I:s], which hid the progression the row is there to show. Only
    the build family needs the override: [Install_lib] and the probes
    already agree with the world. *)
let stage_provision_of_action (act : Canary_basic.action) :
    Canary_artifact.provision option =
  match act with
  | Canary_basic.Configure | Canary_basic.Scan_sources | Canary_basic.Build_lib
  | Canary_basic.Build_headers | Canary_basic.Build_binding _ ->
      Some Canary_artifact.Built
  | _ -> None

(** The provision CHOICE string for one artifact in the scenario:
    [F] fetched (with the pinned version when one exists — the binding
    pin is identity — else the provider suffix, [F:sys] etc.),
    [B:d]/[B:s] built @dev/@stable, [V:d]/[V:s] vendored. Empty when
    absent/unknown. [?stage] is the step's own stage
    ({!stage_provision_of_action}) — it downgrades an [Installed] world's
    build-step cells to [B], and is ignored everywhere else. *)
let provision_choice ?stage
    (pr : Canary_project_run.project_run)
    (a : Canary_artifact.assignment) (id : Canary_artifact.artifact_info) :
    string =
  match Canary_enumerate.placement_of a id with
  | None -> ""
  | Some (pl : Canary_artifact.placement) ->
      let ch =
        match pl.Canary_artifact.version.Canary_basic.channel with
        | Canary_basic.Stable -> ":s"
        | Canary_basic.Dev -> ":d"
      in
      (match pl.Canary_artifact.provision with
       | Canary_artifact.Fetched -> (
           (* a SOURCE names its ref (2026-08-19: it used to be kept bare
              because the row-level [ref] column repeated it — that column
              is now the source's own SETTING cell, so the id belongs
              here); everything else names its provider + version *)
           match Canary_artifact.kind_of id with
           | Canary_basic.Source | Canary_basic.Binding_source _ ->
               let v = pl.Canary_artifact.version.Canary_basic.id in
               if String.is_empty v then "F" else "F " ^ v
           | _ -> fetched_note pr a id)
       | Canary_artifact.Built -> "B" ^ ch
       | Canary_artifact.Installed -> (
           (* the build steps of a staged world name the tree they built;
              install + probe name the staged face *)
           match stage with
           | Some Canary_artifact.Built -> "B" ^ ch
           | _ -> "I" ^ ch)
       | Canary_artifact.Vendored -> "V" ^ ch
       | Canary_artifact.Absent -> "")

(** The full cell annotation: "<kind> <provision>" (e.g. [lib B:d],
    [ocaml F:4.16.0], [lib F:sys]) — explicit about BOTH what the
    action works on and how/at-what it is provided. *)
let cell_annotation ?stage
    (pr : Canary_project_run.project_run)
    (a : Canary_artifact.assignment) (id : Canary_artifact.artifact_info) :
    string =
  let label = kind_label (Canary_artifact.kind_of id) in
  let prov = provision_choice ?stage pr a id in
  if String.is_empty prov then label else label ^ " " ^ prov

(** The actions ONE scenario's steps carry (the {!covered_actions_of}
    per-scenario derivation — derive_steps on the scenario's runner
    spec; the pattern's sig chain omits install/publish steps, so the
    honest chain comes from the step list). *)
let actions_of (pr : Canary_project_run.project_run)
    (a : Canary_artifact.assignment) : Canary_basic.action list =
  (* through {!Canary_pipeline} since 2026-08-24: this used to be a second
     assembly of the stage-4 pass, with its own workspace and project
     name. The throwaway workspace is deliberate and now documented at
     the pipeline — deriving steps APPLIES [pr_runner_spec], which
     materializes a tree for tiny-full. *)
  Canary_pipeline.actions_of pr a

(* ── the ROW order (2026-08-18, user): group by the source REF (the
   project's declared repo family order — the source's store pins),
   then the C lib, then each binding. Within each artifact: provision
   strength (built → vendored → fetched), then the pinned version id.
   Ties keep the enumeration's own order (stable sort). ── *)

let prov_rank = function
  | Canary_artifact.Built -> 0
  | Canary_artifact.Installed -> 1
  | Canary_artifact.Vendored -> 2
  | Canary_artifact.Fetched -> 3
  | Canary_artifact.Absent -> 4

(** One artifact's placement as a sort key: provision strength, then
    the pinned version id. *)
let placement_key (a : Canary_artifact.assignment)
    (id : Canary_artifact.artifact_info) : int * string =
  match Canary_enumerate.placement_of a id with
  | None -> (9, "")
  | Some (pl : Canary_artifact.placement) ->
      (prov_rank pl.Canary_artifact.provision,
       pl.Canary_artifact.version.Canary_basic.id)

(** The binding placement key for one lang (its assignment id by kind —
    mechanism-agnostic). *)
let binding_key (a : Canary_artifact.assignment) (l : Canary_lang.lang) :
    int * string =
  match
    List.find_map a ~f:(fun (id, _) ->
        match Canary_artifact.kind_of id with
        | Canary_basic.Binding l' when Poly.equal l l' -> Some id
        | _ -> None)
  with
  | Some id -> placement_key a id
  | None -> (9, "")

(** The declared REF order: the source artifact's store pins (projected
    from the repo family in declaration order). Undeclared ids sort
    after the declared family. *)
let ref_rank_of (pr : Canary_project_run.project_run) : string -> int =
  let spec = Canary_project_spec.project_spec_of_rows pr.pr_artifacts in
  let pins =
    Canary_artifact.ps_versions_of spec Canary_artifact.a_source
      Canary_artifact.Fetched
  in
  fun id ->
    match
      List.findi pins ~f:(fun _ (b : Canary_basic.build_id) ->
          String.equal b.Canary_basic.id id)
    with
    | Some (i, _) -> i
    | None -> List.length pins

(** The C LIB's row-key: the channel first, so each version's
    built/installed pair sits together (per ref: build row, then
    install row — the "repo × 2" shape), then the provision rank, then
    the version id. The Fetched world sorts LAST (after every built
    family) — the "repo × 2 + 1 fetched" shape. *)
let lib_key (a : Canary_artifact.assignment) : int * int * string =
  match Canary_enumerate.placement_of a Canary_artifact.a_lib with
  | None -> (9, 9, "")
  | Some (pl : Canary_artifact.placement) -> (
      match pl.Canary_artifact.provision with
      | Canary_artifact.Fetched -> (2, 0, "")
      | _ ->
          let chan =
            match pl.Canary_artifact.version.Canary_basic.channel with
            | Canary_basic.Stable -> 0
            | Canary_basic.Dev -> 1
          in
          ( chan,
            prov_rank pl.Canary_artifact.provision,
            pl.Canary_artifact.version.Canary_basic.id ))

(** The full row sort key: (source ref, c lib, OCaml binding, Python
    binding). *)
let row_key (pr : Canary_project_run.project_run)
    (a : Canary_artifact.assignment) =
  let src_id =
    (Canary_enumerate.version_of a Canary_artifact.a_source).Canary_basic.id
  in
  ( ref_rank_of pr src_id,
    lib_key a,
    binding_key a Canary_lang.OCaml,
    binding_key a Canary_lang.Python )

(** Build the matrix over a project list (the bin injects the
    registry). Columns = the sorted union of every project's covered
    actions (the action variant's declaration order); rows = every
    enumerated scenario in the {!row_key} order. *)
(* ── the CANONICAL column order (2026-08-18, user): grouped by the
   ARTIFACT — the native/lib group first, then per LANGUAGE a block of
   the SAME shape (making + fetching + packing + probing the binding,
   then its app), hardcoded since the supported language/mechanism set
   is small — and within each group from the source to the built /
   fetched artifact. Explicit, not the variant's declaration order
   (which interleaves the groups: Probe_lib sits after the binding
   constructors there). The scenario chains follow [store_actions]
   (the catalogue [derive_steps] walks), which is almost this shape —
   the deviations (Probe_lib last, Publish Lib in the tail) are
   recorded for a future catalogue alignment. *)

let binding_group (l : Canary_lang.lang) : int =
  match l with
  | Canary_lang.OCaml -> 1
  | Canary_lang.Python -> 2
  | _ -> 3

let column_group (act : Canary_basic.action) : int =
  match act with
  | Canary_basic.Fetch Canary_basic.Source | Canary_basic.Configure
  | Canary_basic.Scan_sources | Canary_basic.Build_headers
  | Canary_basic.Fetch Canary_basic.Headers | Canary_basic.Build_lib
  | Canary_basic.Fetch Canary_basic.Lib | Canary_basic.Install_lib
  | Canary_basic.Publish Canary_basic.Lib | Canary_basic.Probe_lib
  | Canary_basic.Publish (Canary_basic.Source | Canary_basic.Headers) -> 0
  | Canary_basic.Fetch (Canary_basic.Binding_source l)
  | Canary_basic.Build_binding l
  | Canary_basic.Fetch (Canary_basic.Binding l)
  | Canary_basic.Publish (Canary_basic.Binding l)
  | Canary_basic.Probe_binding l
  | Canary_basic.Build_app { Canary_basic.lang = l; _ }
  | Canary_basic.Probe_app { Canary_basic.lang = l; _ } -> binding_group l
  | Canary_basic.Fetch Canary_basic.App
  | Canary_basic.Publish Canary_basic.App -> 4
  | Canary_basic.Publish (Canary_basic.Binding_source _) -> 4

let column_stage (act : Canary_basic.action) : int =
  match act with
  | Canary_basic.Fetch Canary_basic.Source -> 0
  | Canary_basic.Configure -> 1
  | Canary_basic.Scan_sources -> 2
  | Canary_basic.Build_headers -> 3
  | Canary_basic.Fetch Canary_basic.Headers -> 4
  | Canary_basic.Build_lib -> 5
  | Canary_basic.Install_lib -> 6
  | Canary_basic.Fetch Canary_basic.Lib -> 7
  | Canary_basic.Publish Canary_basic.Lib -> 8
  | Canary_basic.Probe_lib -> 9
  | Canary_basic.Fetch (Canary_basic.Binding_source _) -> 10
  | Canary_basic.Build_binding _ -> 11
  | Canary_basic.Fetch (Canary_basic.Binding _) -> 12
  | Canary_basic.Publish (Canary_basic.Binding _) -> 13
  | Canary_basic.Probe_binding _ -> 14
  | Canary_basic.Build_app _ -> 15
  | Canary_basic.Probe_app _ -> 16
  | Canary_basic.Fetch Canary_basic.App -> 17
  | Canary_basic.Publish Canary_basic.App -> 18
  | Canary_basic.Publish (Canary_basic.Source | Canary_basic.Headers) -> 8
  | Canary_basic.Publish (Canary_basic.Binding_source _) -> 13

(** The canonical column ordering: artifact group, then the source →
    built/fetched stage. *)
let compare_column (x : Canary_basic.action) (y : Canary_basic.action) : int =
  let k a = (column_group a, column_stage a) in
  Stdlib.compare (k x) (k y)

(** The SETTING block's columns: one per declared artifact, union across
    the table's projects in kind order ([kind_order] — source, headers,
    lib, binding, binding-source, app), labelled by {!kind_label}. A
    project that doesn't declare an artifact leaves its cell empty. *)
let setting_columns_of
    (projects : (string * Canary_project_run.project_run) list) :
    (string * Canary_basic.artifact_kind) list =
  (* Keyed by KIND, not by artifact id: the mechanism rides the id's ext
     (binding:ocaml:cstubs vs binding:ocaml:ctypes), so deduping by id
     would give one project's Cstubs binding and another's Ctypes binding
     two columns with the same label. One column per artifact kind (+
     lang); the mechanism is a property of the artifact, not a column. *)
  List.concat_map projects ~f:(fun (_, pr) ->
      List.map (Canary_project_run.artifact_infos pr)
        ~f:Canary_artifact.kind_of)
  |> List.dedup_and_sort ~compare:Stdlib.compare
  |> List.stable_sort ~compare:(fun x y ->
         Stdlib.compare
           (Canary_basic.kind_order x)
           (Canary_basic.kind_order y))
  |> List.map ~f:(fun k -> (kind_label k, k))

let matrix_of (projects : (string * Canary_project_run.project_run) list) :
    t =
  let root = "_out" in
  let setting_cols = setting_columns_of projects in
  let columns =
    List.concat_map projects ~f:(fun (_, pr) ->
        Canary_project_run.covered_actions_of pr)
    |> Stdlib.List.sort_uniq Stdlib.compare
    |> List.stable_sort ~compare:compare_column
    |> List.map ~f:Canary_basic.string_of_action
  in
  let rows =
    List.concat_map projects ~f:(fun (project, pr) ->
        let runs = Canary_status.project_matrix ~root ~project in
        let platform = platform_label () in
        (* rows ordered by ref → c lib → bindings ({!row_key}) *)
        let scenarios =
          List.stable_sort (Canary_project_run.scenarios_of pr)
            ~compare:(fun x y -> Stdlib.compare (row_key pr x) (row_key pr y))
        in
        List.map scenarios ~f:(fun a ->
            let chain_acts = actions_of pr a in
            let chain_tags =
              List.map chain_acts ~f:Canary_basic.string_of_action
            in
            let scenario =
              Stdlib.Filename.basename
                (Canary_project_run.scenario_dir_of ~pr_name:project a)
            in
            let run = run_of_scenario ~scenario runs in
            let repo = source_repo_of pr a in
            let src_id =
              (Canary_enumerate.version_of a Canary_artifact.a_source)
                .Canary_basic.id
            in
            (* the LABEL is the repo's version id — the identity the
               scenario dirs already use ([source-fetched-arbipher]) —
               NOT the literal ref_: latest and the arbipher fork BOTH
               declare ref_ = "HEAD" and would render as identical rows.
               The precise ref (the commit/tag — the VERSION the built
               lib inherits) rides the label as a parenthetical: the
               cell's [lib B:d] then reads as "built at this version".
               The LINK carries the same precise ref. *)
            let ref_label =
              match repo with
              | Some r ->
                  let id = r.Canary_artifact_source.version.Canary_basic.id in
                  let ref_ = r.Canary_artifact_source.ref_ in
                  if String.is_empty id then ref_
                  else if String.equal id ref_ then id
                  else id ^ " (" ^ ref_ ^ ")"
              | None ->
                  (if String.is_empty src_id then "(ambient)" else src_id)
            in
            let ref_url = Option.bind repo ~f:ref_url_of in
            { project;
              scenario;
              index = 0;
              code = "";
              ref_label;
              ref_url;
              platform;
              (* the SETTING block: this world's placement per artifact.
                 A source artifact carries its own repo link — so a
                 project with a lib source AND an off-tree binding source
                 gets two linked cells instead of one ambiguous [ref]. *)
              settings =
                List.map setting_cols ~f:(fun (label, kind) ->
                    (* the project's artifact of this KIND, whatever its
                       mechanism — the row's placement for the column *)
                    match
                      List.find_map a ~f:(fun (id, _) ->
                          if
                            Poly.equal (Canary_artifact.kind_of id) kind
                          then Some id
                          else None)
                    with
                    | None -> (label, None)
                    | Some id ->
                        let text = provision_choice pr a id in
                        let is_src =
                          match kind with
                          | Canary_basic.Source
                          | Canary_basic.Binding_source _ ->
                              true
                          | _ -> false
                        in
                        let repo_here =
                          if is_src then repo_of_source pr a id else None
                        in
                        ( label,
                          Some
                            { text;
                              url = Option.bind repo_here ~f:ref_url_of;
                              title =
                                Option.map repo_here ~f:(fun r ->
                                    r.Canary_artifact_source.name ^ " @ "
                                    ^ r.Canary_artifact_source.ref_) } ));
              cells =
                List.map columns ~f:(fun tag ->
                    if List.mem chain_tags tag ~equal:String.equal then
                      (* the cell's provision choice: the action's
                         primary artifact in THIS scenario (the same
                         action may appear twice — Probe_lib over two
                         locations — one provision either way) *)
                      let provision =
                        match
                          List.find chain_acts ~f:(fun act ->
                              String.equal
                                (Canary_basic.string_of_action act)
                                tag)
                        with
                        | Some act -> (
                            match action_artifact act a with
                            | Some id ->
                                cell_annotation
                                  ?stage:(stage_provision_of_action act) pr a
                                  id
                            | None -> "")
                        | None -> ""
                      in
                      ( tag,
                        Some
                          { mark = mark_of_run ~run tag;
                            provision;
                            detail = detail_of_run ~run tag } )
                    else (tag, None)) }))
  in
  (* the GLOBAL row index: the ordinal follows the rendered row order;
     the code is the stable digest of the row's identity (project +
     scenario) — insertion-safe, so a historical run's row keeps its
     code. Display-only: nothing here feeds a cache key or scenario
     identity. *)
  let rows =
    List.mapi rows ~f:(fun i (r : row) ->
        { r with
          index = i + 1;
          code =
            Stdlib.Digest.string (r.project ^ "/" ^ r.scenario)
            |> Stdlib.Digest.to_hex |> fun s -> String.prefix s 6 })
  in
  { setting_columns = List.map setting_cols ~f:fst; columns; rows }

(* ── text renderer ── *)

(** Per-project grouped sections; columns with no chain presence in
    the group are elided (the honest blank is invisible, not a glyph). *)
let pp_text (m : t) : unit =
  let groups =
    List.group m.rows ~break:(fun a b ->
        not (String.equal a.project b.project))
  in
  let width = 14 in
  List.iter groups ~f:(fun group ->
      (match group with
       | [] -> ()
       | (r : row) :: _ ->
           (* a column is in the group when any row's cell is non-None *)
           let used =
             List.filter m.columns ~f:(fun tag ->
                 List.exists group ~f:(fun (rr : row) ->
                     match
                       List.Assoc.find rr.cells tag ~equal:String.equal
                     with
                     | Some (Some _) -> true
                     | _ -> false))
           in
           let pad s =
             if String.length s >= width then s ^ " "
             else s ^ String.make (width - String.length s) ' '
           in
           (* the terminal view is column-aligned, so an over-long setting
              (a verbose declared package) is elided rather than allowed to
              shift the row; md/html/json carry it in full *)
           let fit s =
             if String.length s <= width - 1 then s
             else String.prefix s (width - 2) ^ "…"
           in
           (* the SETTING block, elided per group like the action columns:
              only the artifacts THIS project declares *)
           let set_used =
             List.filter m.setting_columns ~f:(fun label ->
                 List.exists group ~f:(fun (rr : row) ->
                     match
                       List.Assoc.find rr.settings label ~equal:String.equal
                     with
                     | Some (Some _) -> true
                     | _ -> false))
           in
           Fmt.pr "@.%s — %d scenario(s)@." r.project (List.length group);
           Fmt.pr "  %s%s| %s@." (pad "#")
             (String.concat ~sep:"" (List.map set_used ~f:pad))
             (String.concat ~sep:"" (List.map used ~f:pad));
           List.iter group ~f:(fun (rr : row) ->
               let cells =
                 List.map used ~f:(fun tag ->
                     match
                       List.Assoc.find rr.cells tag ~equal:String.equal
                     with
                     | Some (Some c) -> pad c.mark
                     | Some None -> pad ""
                     | None -> pad "")
               in
               let sets =
                 List.map set_used ~f:(fun label ->
                     match
                       List.Assoc.find rr.settings label ~equal:String.equal
                     with
                     | Some (Some s) -> pad (fit s.text)
                     | _ -> pad "—")
               in
               (* the global row index: "#N" for fast pointing; the
                  stable code is the historical pointer (see {!row.code}) *)
               Fmt.pr "  %s%s| %s@."
                 (pad (Printf.sprintf "#%d" rr.index))
                 (String.concat ~sep:"" sets)
                 (String.concat ~sep:"" cells))));
  let total = List.length m.rows in
  Fmt.pr "@.legend: ✓ done · not run ⊘ blocked xfail[cN] expected failure (cN confirming contracts) ✗ failed@.";
  Fmt.pr "%d scenario(s) across %d project(s)@." total
    (List.length (List.dedup_and_sort ~compare:String.compare (List.map m.rows ~f:(fun r -> r.project))))

(* ── markdown renderer (GH-renderable) ── *)

let pp_md (m : t) : unit =
  List.iter (List.group m.rows ~break:(fun a b ->
      not (String.equal a.project b.project))) ~f:(fun group ->
      match group with
      | [] -> ()
      | (r : row) :: _ ->
          let used =
            List.filter m.columns ~f:(fun tag ->
                List.exists group ~f:(fun (rr : row) ->
                    match
                      List.Assoc.find rr.cells tag ~equal:String.equal
                    with
                    | Some (Some _) -> true
                    | _ -> false))
          in
          let set_used =
            List.filter m.setting_columns ~f:(fun label ->
                List.exists group ~f:(fun (rr : row) ->
                    match
                      List.Assoc.find rr.settings label ~equal:String.equal
                    with
                    | Some (Some _) -> true
                    | _ -> false))
          in
          Fmt.pr "### %s@." r.project;
          Fmt.pr "| # | %s | %s | scenario |@."
            (String.concat ~sep:" | " set_used)
            (String.concat ~sep:" | " used);
          Fmt.pr "| --- | %s | %s | --- |@."
            (String.concat ~sep:" | " (List.map set_used ~f:(fun _ -> "---")))
            (String.concat ~sep:" | " (List.map used ~f:(fun _ -> "---")));
          List.iter group ~f:(fun (rr : row) ->
              let cells =
                List.map used ~f:(fun tag ->
                    match
                      List.Assoc.find rr.cells tag ~equal:String.equal
                    with
                    | Some (Some c) -> c.mark
                    | Some None -> " "
                    | None -> " ")
              in
              let sets =
                List.map set_used ~f:(fun label ->
                    match
                      List.Assoc.find rr.settings label ~equal:String.equal
                    with
                    | Some (Some s) -> s.text
                    | _ -> "—")
              in
              (* the scenario id stays as the LAST column: the setting
                 block names the world, but the id is what `_out` dirs and
                 `canary status` are keyed by *)
              Fmt.pr "| #%d | %s | %s | %s |@." rr.index
                (String.concat ~sep:" | " sets)
                (String.concat ~sep:" | " cells)
                rr.scenario);
          Fmt.pr "@.")

(* ── JSON ── *)

let to_json (m : t) : Yojson.Basic.t =
  `Assoc
    [ ( "setting_columns",
        `List (List.map m.setting_columns ~f:(fun c -> `String c)) );
      ( "columns",
        `List (List.map m.columns ~f:(fun c -> `String c)) );
      ( "rows",
        `List
          (List.map m.rows ~f:(fun (r : row) ->
               `Assoc
                 [ ("project", `String r.project);
                   ("scenario", `String r.scenario);
                   ("index", `Int r.index);
                   ("code", `String r.code);
                   ( "settings",
                     `Assoc
                       (List.filter_map r.settings ~f:(fun (label, s) ->
                            match s with
                            | Some s -> Some (label, `String s.text)
                            | None -> None)) );
                   ( "cells",
                     `Assoc
                       (List.filter_map r.cells ~f:(fun (tag, c) ->
                            match c with
                            | Some c -> Some (tag, `String c.mark)
                            | None -> None)) ) ])) )
    ]

(* ── HTML (the web page) ── *)

(** Self-contained page: the full union-column table — project | ref
    (linked to the remote commit/tree) | platform | actions — colored
    cells showing the provision choice + the verdict. The long
    scenario ids live in the cell tooltips. The styling mirrors
    {!Canary_html}'s badge tones without importing its machinery. *)
let render_html (m : t) ~(generated_at : string) : string =
  let esc s =
    s
    |> String.substr_replace_all ~pattern:"&" ~with_:"&amp;"
    |> String.substr_replace_all ~pattern:"<" ~with_:"&lt;"
    |> String.substr_replace_all ~pattern:">" ~with_:"&gt;"
  in
  let cell_cls mark =
    match mark with
    | "" -> "blank"
    | "·" -> "notrun"
    | "⊘" -> "blocked"
    | "✗" -> "fail"
    | s when String.is_prefix s ~prefix:"xfail" -> "xfail"
    | _ -> "ok"
  in
  (* the SETTING block leads (2026-08-19, user): the world first — one
     column per artifact — then the actions. The old single [ref] column
     is gone: the source artifacts' own setting cells carry the ref and
     its link, so a project with two sources shows two labelled refs
     instead of one column that meant a different artifact per project. *)
  let header =
    (* the two identity columns are FROZEN (2026-08-20, user: the page is
       too wide): they stay put while the action columns scroll, so a row
       never loses its number and project. The classes carry the sticky
       offsets — see the [idx]/[proj] rules in the style block. *)
    "<th class=\"idx\">#</th><th class=\"proj\">project</th>"
    ^ String.concat ~sep:""
        (List.map m.setting_columns ~f:(fun c ->
             "<th class=\"seth\">" ^ esc c ^ "</th>"))
    ^ "<th class=\"platform\">platform</th>"
    ^ String.concat ~sep:""
        (List.map m.columns ~f:(fun c -> "<th>" ^ esc c ^ "</th>"))
  in
  let body =
    String.concat ~sep:""
      (List.map m.rows ~f:(fun (r : row) ->
           let setting_cells =
             String.concat ~sep:""
               (List.map m.setting_columns ~f:(fun label ->
                    match
                      List.Assoc.find r.settings label ~equal:String.equal
                    with
                    | Some (Some s) ->
                        let title =
                          match s.title with
                          | Some t -> t ^ " · " ^ r.scenario
                          | None -> r.scenario
                        in
                        let inner =
                          match s.url with
                          | Some url ->
                              Printf.sprintf "<a href=\"%s\">%s</a>" (esc url)
                                (esc s.text)
                          | None -> esc s.text
                        in
                        Printf.sprintf
                          "<td class=\"set\" title=\"%s\">%s</td>" (esc title)
                          inner
                    (* the project doesn't declare this artifact — an
                       honest blank, not a glyph *)
                    | _ -> "<td class=\"blank\"></td>"))
           in
           let cells =
             String.concat ~sep:""
               (List.map m.columns ~f:(fun tag ->
                    match
                      List.Assoc.find r.cells tag ~equal:String.equal
                    with
                    | Some (Some c) ->
                        (* the tooltip's third part is the verdict's
                           DETAIL — the reason (the xfail's
                           confirmed-expected-failure text names the
                           fix; a failure's postcondition message) *)
                        let why =
                          match c.detail with
                          | Some d -> " · " ^ d
                          | None -> ""
                        in
                        (* the action cell is a MARK (2026-08-19): the
                           artifact's provision moved to the setting
                           block, so it no longer repeats in every cell —
                           it stays in the tooltip, where the per-STEP
                           stage still distinguishes "built it" from
                           "staged it" *)
                        Printf.sprintf
                          "<td class=\"%s\" title=\"%s · %s · %s%s\"><span class=\"mk\">%s</span></td>"
                          (cell_cls c.mark) (esc r.scenario) (esc tag)
                          (esc c.provision) (esc why) (esc c.mark)
                    | _ -> "<td class=\"blank\"></td>"))
           in
           Printf.sprintf
             "<tr><td class=\"idx\" title=\"%s\">%d</td><td class=\"proj\">%s</td>%s<td class=\"platform\">%s</td>%s</tr>"
             (esc r.code) r.index (esc r.project) setting_cells
             (esc r.platform) cells))
  in
  Printf.sprintf
    {|<!doctype html>
<html><head><meta charset="utf-8"><title>canary result matrix</title>
<style>
/* THE SCROLL BOX (2026-08-20, user: "the page is too width"). The wrap
   always had overflow-x, but its scrollbar sat under 42 rows of table —
   you had to scroll to the bottom of the PAGE to find the control that
   moved the table sideways, which reads as "no scroller at all".

   The page is now a flex column pinned to the viewport, so the wrap gets
   exactly the leftover height and owns BOTH scrollbars. A calc() on the
   header height would have worked until the meta paragraph rewrapped;
   flex measures it instead of guessing. [min-height: 0] on the flex item
   is the part that is easy to omit — without it a flex child refuses to
   shrink below its content and the box overflows the viewport again. */
html, body { height: 100%%; }
body { font-family: system-ui, sans-serif; margin: 0; padding: 1.5rem 2rem;
       box-sizing: border-box; color: #24292f;
       display: flex; flex-direction: column; }
h1 { font-size: 1.4rem; margin: 0 0 .5rem; flex: 0 0 auto; }
.meta { color: #6a737d; font-size: .85rem; margin-bottom: 1rem; flex: 0 0 auto;
        max-height: 7rem; overflow-y: auto; }
.wrap { flex: 1 1 auto; min-height: 8rem; overflow: auto;
        border: 1px solid #d0d7de; border-radius: 6px; }
table { border-collapse: separate; border-spacing: 0; font-size: .82rem; }
th, td { padding: 4px 8px; border-bottom: 1px solid #eaeef2; white-space: nowrap; text-align: left; }
th { background: #f6f8fa; position: sticky; top: 0; z-index: 2; }
/* the two identity columns are FROZEN: scrolling right must not cost you
   the row's number and project, which are how a row is referred to */
td.idx, th.idx { position: sticky; left: 0; width: 2.6rem; min-width: 2.6rem; z-index: 1; background: #fff; }
td.proj, th.proj { position: sticky; left: 2.6rem; width: 5.2rem; min-width: 5.2rem; z-index: 1;
                   background: #fff; border-right: 1px solid #d0d7de; }
th.idx, th.proj { background: #f6f8fa; z-index: 3; }
td.set { font-family: ui-monospace, monospace; font-size: .78rem; background: #f6f8fa88; }
td.set a { color: #0969da; text-decoration: none; }
td.set a:hover { text-decoration: underline; }
th.seth { background: #eef1f4; }
td.platform { color: #57606a; font-size: .75rem; }
td.idx { color: #57606a; font-size: .75rem; text-align: right; }
td .prov { color: #57606a; font-family: ui-monospace, monospace; font-size: .7rem; margin-right: 5px; }
td .mk { font-weight: 600; }
td.ok { background: #dafbe1; } td.xfail { background: #fff8c5; }
td.fail { background: #ffebe9; } td.fail .mk { font-weight: 800; }
td.notrun { color: #8c959f; } td.blocked { color: #57606a; background: #f6f8fa; }
td.blank { background: #f6f8fa; }
</style></head><body>
<h1>canary result matrix</h1>
<div class="meta">generated %s — rows = project × scenario (one enumerated world each). The SHADED leading columns are the world's SETTING: one per declared artifact, showing its placement (F = fetched, B = built, I = installed/staged, V = vendored; source cells link to the ref). The action columns then carry verdicts only — hover a cell for the scenario id, the artifact's stage, and the reason. The # column is the global row index (hover it for the stable row code — the historical pointer). Pre/post-check columns: future.</div>
<div class="wrap"><table><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>
</body></html>|}
    (esc generated_at) header body

(* The web file locations (the docs copy is the GH Pages view). *)
let web_path ~projects_root = projects_root ^ "/matrix.html"

let docs_path = "docs/canary/projects/matrix.html"

let write_web ~projects_root (m : t) ~(generated_at : string) : unit =
  let html = render_html m ~generated_at in
  List.iter [ web_path ~projects_root; docs_path ] ~f:(fun path ->
      let oc = Stdlib.open_out path in
      Stdlib.output_string oc html;
      Stdlib.close_out oc);
  Fmt.pr "Wrote %s and %s (%d rows)@." (web_path ~projects_root)
    docs_path (List.length m.rows)

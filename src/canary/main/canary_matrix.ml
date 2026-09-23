open Base

(* ── The result table (2026-08-17, user) ──
   A cross-project verdict matrix: ROWS = project × scenario (the
   ENUMERATED worlds — a stable shape, never-run scenarios show all
   [·]), COLUMNS = actions (the union across the registry in
   catalogue order). Cells carry the last-run verdict from the shared
   actions.log (via {!Canary_status.project_log} — the only
   per-scenario run record). The future extension: pre/post-check
   columns ("each checks") appended to the action set.

   Rendered in the cmd (text/md/json) and as the web page
   [docs/canary/projects/matrix.html]. Pure read — no execution. *)

(** WHAT A CELL'S MARK WAS RENDERED FROM (2026-09-23, status.md §2.7
    phase A — the record a run overlay reads). The mark is for a reader
    scanning a table and it is lossy on purpose: a warm skip and a real
    run both print ✓, and [violated] and [error] both print ✗. A program
    drawing a run needs the value, so the cell carries it and the mark is
    its rendering. *)
type recorded =
  | R_act of Canary_status.step_state
  | R_check of string option
      (** the agreement outcome label ([holds], [violated],
          [unavailable] …); [None] = no recorded run evaluated it *)
  | R_artifact
      (** an artifact column: the mark IS the reading, a summary of the
          inspection the step left on disk *)

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
type cell = {
  mark : string;
  recorded : recorded;
  at : string option;
      (** WHEN the log recorded what this cell shows — the timestamp of
          the verdict or outcome line that won. Per cell rather than per
          row because the table is last-wins over every run the log
          holds, so one row's cells can come from different runs. Local
          wall-clock time with no zone ({!Canary_status.stamp_of_line}).
          [None] for an artifact cell and for a cell nothing recorded. *)
  provision : string;
  detail : string option;
  blame : string option;
      (** WHY this cell carries no verdict, or why the verdict is
          suspect (2026-09-15, user: "before we fix that, can we
          attribute it as one thing to blame in the table, so we can
          see how eager we need to fix it").

          A closed vocabulary, because the point is to COUNT it. See
          {!blame_of} for what each word means and how it is derived —
          the important property is that every one of them is a static
          scan of the project spec plus the cell's recorded outcome, so
          a blame can be attributed before the thing it blames is
          fixed. [None] on a cell that is simply fine. *)
}

(** ONE STEP OF A WORLD, as the record carries it (2026-09-23, status.md
    §2.7 phase B1). The cells hold one entry per ACTION, and a world has
    more steps than that: a lib probe per location ([probe_lib_apt]), a
    package-linked consumer beside the artifact-linked one
    ([probe_binding_ocaml_opam]), an inspection after each artifact it
    summarizes. The overview joins STEPS onto its edges, so the record
    lists every step the realize pass derives for the world — typed as
    the builder typed it, in the state its log line says. *)
type world_step = {
  ws_tag : string;
  ws_action : Canary_basic.action;
  ws_location : Canary_store.location option;
      (** where a probe looks — [Canary_step_model.step.location] *)
  ws_inspects : string option;
      (** the step an inspection summarizes; [None] for a step that
          performs its action *)
  ws_dummy : string option;
      (** a dummy step's reason for being empty ([Canary_step_model]) *)
  ws_place : Canary_topology.place;
      (** WHERE IT SITS on the overview's graph (phase B2): the edges it
          realizes, the step it is evidence for, or why it has no edge *)
  ws_state : Canary_status.step_state;
  ws_at : string option;
  ws_detail : string option;
}

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
  implicated : string option;
      (** WHICH CHECK IN THIS ROW READ THIS ARTIFACT AND FAILED
          (2026-09-14, user: "if any check fails, we can mark the check
          and the involved artifact in the same red").

          A failing action cell says a step went wrong; it does not say
          which of the artifacts the step combined is at fault. A
          failing AGREEMENT does better, because its evidence names
          what it read — so the row can colour the artifacts that
          violation was about.

          It says WHICH check rather than just "bad", because the two
          reference kinds mean different things here: a declaration
          comparison implicates one artifact ("this is not what you
          said you ship") and a peer comparison implicates two ("these
          disagree", with no claim about which is wrong). The text
          carries the agreement name so the distinction survives into
          the tooltip. *)
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
      (** the platform this TABLE is rendered for ({!platform_label}) —
          the page's column. Not what the run saw: see [recorded_on] *)
  recorded_on : string list;
      (** the platform(s) the run LOGGED for this world
          ({!Canary_status.scenario_log}), which is what a record of a
          run must carry (2026-09-23, status.md §2.7). It differs from
          [platform] exactly when it matters — a mac run's log read on
          WSL, or a [--platform] render. [] = the log recorded none *)
  settings : (string * setting option) list;
      (** per SETTING column (artifact label) in column order; [None] =
          the project does not declare that artifact *)
  cells : (string * cell option) list;
      (** per column tag in column order; [None] = not in the chain *)
  steps : world_step list;
      (** every step of this world, in the realize pass's order — the
          record's view, which no text renderer draws (status.md §2.7
          B1) *)
  edges : (string * string list) list;
      (** THE JOIN, per edge of the overview's graph that this world
          REALIZES: the tags of the steps realizing it, in edge order
          (phase B2). An edge absent here is dead in this world *)
  claims : (string * (string * string option) list) list;
      (** per claim the overview places on an edge ([Canary_topology]'s
          claim sites) that has a check column in this row: each column
          and its outcome ([None] = no run evaluated it) *)
}

(** A COLUMN IS AN ACTION OR A CHECK SLOT (2026-09-14, user).

    The chain reads [action, artifact, action, artifact …], so a check
    has a place in it: [Check (a, Pre)] states what [a] needs before it
    runs, [Check (a, Post)] validates what it made. Both sit adjacent
    to [a], which is what makes a failing check legible — the reader
    does not have to work out which step it was talking about.

    The check columns are DERIVED from the registry's [ag_slot], not
    from the log: a scenario that has never run still shows its check
    columns, all [·], exactly as it shows its action columns. Filling
    them from the log instead would make the table's shape depend on
    what happened to be run, which is the property this table has
    always avoided. *)
type col =
  | Act of Canary_basic.action
  | Check of Canary_basic.action * Canary_agreement_common.stage * string
      (** ONE AGREEMENT PER COLUMN (2026-09-14, user: "not 2/3 in one
          cell, but one check per cell"). The aggregate cell said two
          of the three claims here reached a verdict and would not say
          WHICH — so a reader who wanted the answer had to hover, and a
          reader scanning a column could not compare rows.

          The cost is width, and it is paid down by only giving a
          column to a claim that can actually be decided at that point:
          one with an evaluator, applicable in at least one of the
          project's worlds. A planned agreement would be a column of
          dots forever, and a claim the mechanism cannot carry — three
          of the six at an OCaml cstubs probe — would be a column of
          [not_applicable]. Neither is worth 14 characters. *)
  | Artifact of Canary_basic.action
      (** WHAT THE ACTION LEFT BEHIND (2026-09-14, user). The chain
          reads [action, artifact, action, artifact …] and until now
          the table showed only the first of each pair, plus the
          world's placements in the leading block. Those say what a
          scenario IS; this says what each step actually produced, read
          back off the inspection the step wrote.

          Only where an inspection EXISTS — same omit-empty rule as the
          check columns. A column of blanks would be worse than no
          column, and an artifact with nothing recorded about it has
          nothing concise to show. *)

type t = {
  setting_columns : string list;
      (** the leading block: one artifact label per declared artifact,
          union across the table's projects in kind order *)
  columns : string list;
  typed_columns : col list;
      (** the same columns, TYPED — [columns] is their labels, in the
          same order (2026-09-23, status.md §2.7 finding 3). The JSON
          record exports these, because a label is a string a consumer
          would have to parse back into an action, a slot and an
          agreement, and the join onto the overview's edges wants the
          action itself *)
  check_columns : string list;
      (** which of [columns] are CHECK slots rather than actions. The
          labels are self-describing ([probe_binding_ocaml_pre]), but a
          renderer should not have to parse a suffix to find that out —
          that is how the xfail reader came to look for a literal "[c".
          Text mode also uses it to abbreviate: a check column always
          sits next to the action it names, so the action half of its
          label is redundant on screen and merely widens an already
          wide table. *)
  artifact_columns : string list;
      (** which of [columns] hold an ARTIFACT SUMMARY rather than a
          verdict or a check. Named for the same reason
          [check_columns] is: a renderer should ask, not parse a
          suffix. Their cells carry a summary in [mark] and use
          [detail] only to say a check that read them failed, so
          "is this cell red" is a different question here than
          anywhere else in the table. *)
  rows : row list;
}

(** The scenario's part of the log ([None] when the project has no
    actions.log or the scenario never logged a verdict). *)
let log_of_scenario ~scenario (logs : Canary_status.scenario_log list) :
    Canary_status.scenario_log option =
  List.find logs ~f:(fun (sl : Canary_status.scenario_log) ->
      String.equal sl.Canary_status.sl_scenario scenario)

(** One ACTION cell's reading of the log: the step's typed state, and —
    when a line recorded it — that line's timestamp and its DETAIL, the
    event's reason (the xfail's "expected failure confirmed: … predates
    …" names the fix; a failure's "postcondition failed"/command output
    explains it — the tooltip content the user asked for). *)
let reading_of_run (sl : Canary_status.scenario_log option) (tag : string) :
    Canary_status.step_state * string option * string option =
  match
    Option.bind sl ~f:(fun (sl : Canary_status.scenario_log) ->
        List.Assoc.find sl.Canary_status.sl_verdicts tag ~equal:String.equal)
  with
  | None -> (Canary_status.Unrecorded, None, None)
  | Some (l : Canary_status.logged) ->
      ( Option.value
          (Canary_status.state_of_event l.Canary_status.lg_event
             l.Canary_status.lg_detail)
          ~default:Canary_status.Unrecorded,
        (if String.is_empty l.Canary_status.lg_at then None
         else Some l.Canary_status.lg_at),
        l.Canary_status.lg_detail )

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

(** The live installed version of a system package (memoized — the
    matrix's one runtime read; "" when unknown).

    ASK THE PM THIS MACHINE HAS (2026-08-26). This was an unconditional
    [dpkg-query], which on macOS returns nothing for every package: the
    fetched-lib cells silently lost their version and rendered as a bare
    [brew z3] where Linux shows [apt z3.4.8.12]. Version-less is exactly
    the thing the FETCHED annotation exists to prevent ("we DO know it"),
    and it fails quietly — no error, just a thinner cell. [brew list
    --versions] prints "<formula> <version>", so the last field is the
    answer; an uninstalled formula prints nothing, which is the same ""
    the dpkg branch yields. *)
let sys_pkg_versions : (string, string) Hashtbl.t =
  Hashtbl.create (module String)

(* through the PM dispatcher (2026-08-26): this had its own dpkg/brew
   branches, duplicating what the per-PM drivers already knew. A cell
   that asks the store a question should ask it the way every other
   caller does — [Canary_pm.installed_version_cmd] is that hub. *)
let sys_pkg_version_cmd (pkg : string) : string =
  Canary_pm.installed_version_cmd (Canary_store.detect_pm ()) ~pkg

let sys_pkg_version (pkg : string) : string =
  match Hashtbl.find sys_pkg_versions pkg with
  | Some v -> v
  | None ->
      let v =
        let ic = Unix.open_process_in (sys_pkg_version_cmd pkg) in
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
(* ── the CANONICAL column order (2026-08-18, user) ──

   MOVED TO [Canary_basic] on 2026-09-14. It is a pure function of
   [action] and two orderings existed — this one and the agreement
   views' — which could not share while it lived in [main/]; that is
   the layering [backlog.md] §51 records. The agreement catalogue
   now sorts its summary table by the same key, so the two tables list
   their rows in one order.

   The shape it encodes: grouped by the ARTIFACT, the native/lib group
   first, then per LANGUAGE a block of the same shape, and within each
   group from the source to the built/fetched artifact. The scenario
   chains follow [store_actions], which is almost this shape — the
   deviations (Probe_lib last, Publish Lib in the tail) are recorded
   for a future catalogue alignment. *)

let compare_column = Canary_basic.compare_column

(* [type col] is defined with the other matrix types, above [t], since
   2026-09-23: [t] carries the typed columns now. *)

(* the kind an artifact column's action produces — the half of its label
   after the [=], and the record's [artifact] field *)
let produced_label (a : Canary_basic.action) : string =
  match Canary_action.produces_of_action a with
  | k :: _ -> kind_label k
  | [] -> "?"

let label_of_col = function
  | Act a -> Canary_basic.string_of_action a
  | Check (a, s, slug) ->
      (* THE SHORT CODE IS THE NAME (2026-09-14, user), not a terminal
         abbreviation of a longer one. [build_lib_post:dse] is exactly
         as unique as [build_lib_post:declared_symbols_exported] — the
         slot already disambiguates — so carrying both meant one column
         had two names, and which you saw depended on the renderer.
         One name, in every medium, with the key explaining it. *)
      Canary_agreement_common.string_of_slot (a, s) ^ ":"
      ^ Canary_agreement_common.short_code_of_slug slug
  | Artifact a ->
      (* NAMES THE ARTIFACT, not another stage (2026-09-14, user asked
         when [build_lib_out] "runs" — it does not, and a label that
         reads like a stage suffix beside [build_lib_post] invited
         exactly that). A check column is a verdict; this is a THING,
         so the label says which thing: [build_lib=lib] reads as "and
         build_lib produced the lib".

         The action stays in the label because it is what makes the
         column UNIQUE — two actions can produce the same kind
         ([build_lib] and [fetch_lib] both yield [Lib]) and the cells
         are keyed by label. *)
      Canary_basic.string_of_action a ^ "=" ^ produced_label a

let action_of_col = function Act a | Check (a, _, _) | Artifact a -> a

(** [pre], the action, what it MADE, then the verdict on it
    (2026-09-14, user). The artifact comes before the post-check
    because the check is a verdict ABOUT the artifact, and a verdict
    printed to the left of the thing it judges reads backwards. *)
let col_rank = function
  | Check (_, Canary_agreement_common.Pre, _) -> 0
  | Act _ -> 1
  | Artifact _ -> 2
  | Check (_, Canary_agreement_common.Post, _) -> 3

let compare_col (x : col) (y : col) : int =
  let a = action_of_col x and b = action_of_col y in
  match compare_column a b with
  | 0 -> Stdlib.compare (col_rank x) (col_rank y)
  | n -> n

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

(** The languages a chain's actions mention — the ones whose slots can
    resolve in it. A project with no per-language action still needs
    one entry, because a lib-side slot ignores the language entirely. *)
let langs_of_chain (chain : Canary_basic.action list) : Canary_lang.lang list =
  let ls =
    List.filter_map chain ~f:(fun a ->
        match a with
        | Canary_basic.Build_binding l
        | Canary_basic.Probe_binding l
        | Canary_basic.Fetch (Canary_basic.Binding l)
        | Canary_basic.Build_app { lang = l } ->
            Some l
        | _ -> None)
    |> List.dedup_and_sort ~compare:Stdlib.compare
  in
  if List.is_empty ls then [ Canary_lang.OCaml ] else ls

(** Which check columns this chain offers: every registered agreement's
    slot, resolved against the actions this scenario actually contains,
    for each language the chain mentions. An agreement whose candidates
    are all absent contributes nothing — which is how a project that
    builds no app avoids a [build_app_ocaml_pre] column. *)
let check_cols_of_chain (chain : Canary_basic.action list)
    ~(an : Canary_project_analysis.t) : col list =
  List.concat_map Canary_agreement.agreement_registry ~f:(fun r ->
      List.concat_map (langs_of_chain chain) ~f:(fun lang ->
          (* CAN THIS CLAIM BE DECIDED HERE AT ALL? PASS 2's answer
             (2026-09-16), not a local one. The two filters are still
             the two filters — a method with no evaluator reports
             [not_implemented] forever, one this project cannot carry
             reports [not_applicable] forever, neither is coverage —
             but they are applied once, in
             [Canary_project_analysis.carried_slugs], and this asks.

             THE LATENT HALF, which is why this is worth a pass and not
             a shared helper. This used to compute the mechanism as
             [mechanism_of_lang_exn lang] — the LANGUAGE DEFAULT — while
             [Canary_check_index] asked the same question with what the
             project DECLARES. The two answers differ wherever a project
             declares a non-default mechanism (z3 and llvm bind Python
             through Ctypes; the default is Cext), and applicability
             genuinely turns on it: Ctypes compiles no stub and records
             no dependency. No output moved when this changed, because
             no project's chain puts such a language in front of THIS
             function — llvm derives no Python step at all and z3 is
             muted. A divergence that costs nothing today and flips a
             column the day a project grows one is exactly the shape the
             2026-09-15 Python instance had before it fired.

             Applicability takes no world — it is a static property of
             the project — which is why the question can be answered a
             pass before any assignment exists. *)
          if
            not
              (r.Canary_agreement.ag_enabled
              && Canary_project_analysis.carries an ~lang
                   r.Canary_agreement.ag_slug)
          then []
          else
            Option.to_list
              (Option.map
                 (Canary_agreement_common.slot_in_chain
                    r.Canary_agreement.ag.Canary_agreement_common.ag_slot ~lang
                    ~chain)
                 ~f:(fun (a, s) -> Check (a, s, r.Canary_agreement.ag_slug)))))
  |> List.dedup_and_sort ~compare:Stdlib.compare

(** WHICH ACTIONS LEAVE AN INSPECTABLE ARTIFACT — an action that
    produces something, and whose own step tag some agreement reads
    evidence from. Both halves matter: a probe produces nothing
    ([produces_of_action] is empty for every [Probe_*] — they verify,
    they do not create), and an action nobody reads evidence from has
    no inspection to show.

    Derived from the registry's evidence paths rather than from disk,
    for the same reason the check columns are: the table's shape must
    not depend on what happened to be run. *)
let artifact_cols_of_chain (chain : Canary_basic.action list)
    ~(world : Canary_artifact.assignment)
    ~(an : Canary_project_analysis.t) : col list =
  let read_tags =
    List.concat_map (langs_of_chain chain) ~f:(fun lang ->
        List.concat_map Canary_agreement.agreement_registry ~f:(fun r ->
            List.concat_map
              r.Canary_agreement.ag.Canary_agreement_common.ag_methods
              ~f:(fun m ->
                List.concat_map
                  (m.Canary_agreement_common.m_inputs
                     { Canary_agreement_common.ac_mechanism =
                         (* pass 2's mechanism, for the same reason
                            [check_cols_of_chain] takes it: what a
                            method READS can depend on the mechanism,
                            and a language default is a guess *)
                         Canary_project_analysis.mechanism_for an lang;
                       ac_lang = lang;
                       ac_world = world;
                       ac_declared = an.Canary_project_analysis.an_declared })
                  ~f:Canary_agreement_common.paths_of_input)))
    |> List.filter_map ~f:(fun p ->
           match String.lsplit2 p ~on:'/' with
           | Some (t, _) -> Some t
           | None -> None)
    |> List.dedup_and_sort ~compare:String.compare
  in
  List.filter chain ~f:(fun a ->
      (not (List.is_empty (Canary_action.produces_of_action a)))
      && List.mem read_tags
           (Canary_basic.string_of_action a)
           ~equal:String.equal)
  |> List.map ~f:(fun a -> Artifact a)

(** THE ONE LINE AN INSPECTION IS WORTH, per kind. Concise because the
    column is 14 characters wide and because the point is a glance:
    what this artifact is and how much of it there is. The full record
    is what [canary artifact-summary] and the tooltip are for.

    Kind-dispatched rather than generic — a library's headline is its
    identity and export count, a binding surface's is how many names it
    offers, a compiled stub's is how many it demands. Printing
    "counts.total" for all three would be uniform and useless. *)
let summarize_inspection (j : Yojson.Basic.t) : string option =
  let str k = match Canary_agreement_common.field j k with
    | Some (`String s) -> Some s | _ -> None
  in
  let int_at path =
    match
      List.fold path ~init:(Some j) ~f:(fun acc k ->
          Option.bind acc ~f:(fun x -> Canary_agreement_common.field x k))
    with
    | Some (`Int n) -> Some n
    | _ -> None
  in
  let len k =
    match Canary_agreement_common.field j k with
    | Some (`List xs) -> Some (List.length xs)
    | _ -> None
  in
  match str "kind" with
  | Some "native" ->
      let n = Option.value (int_at [ "counts"; "total" ]) ~default:0 in
      let soname =
        match Canary_agreement_common.field j "elf" with
        | Some e -> (
            match Canary_agreement_common.field e "soname" with
            | Some (`String s) when not (String.is_empty s) -> (
                (* the VERSIONED TAIL is the part that varies and the
                   part a mismatch turns on — the library's name is
                   already the setting column beside it, so repeating
                   "libsqlite3" costs ten characters to say nothing *)
                match String.substr_index s ~pattern:".so" with
                | Some i -> String.drop_prefix s (i + 1)
                | None -> s)
            | _ -> "-")
        | None -> "-"
      in
      Some (Printf.sprintf "%s %d" soname n)
  | Some ("ocaml" | "ocaml_mli") ->
      Option.map (len "modules") ~f:(Printf.sprintf "%d mod")
  | Some "c_stub" -> Option.map (len "requires") ~f:(Printf.sprintf "%d req")
  | Some "python" -> Option.map (len "attrs") ~f:(Printf.sprintf "%d attr")
  | _ -> None

(** The inspection a step wrote, if it wrote one. [attach_inspect]
    puts a step's summary in the step's OWN output dir, so this needs
    no per-project knowledge and cannot drift from where the inspector
    actually writes. *)
let inspection_of_step ~(root : string) ~(project : string)
    ~(scenario : string) (tag : string) : Yojson.Basic.t option =
  let file =
    Canary_basic.filename ~variant_key:scenario ~base:"inspect" ~ext:"json"
  in
  let path =
    Printf.sprintf "%s/canary/projects/%s/%s/%s" root project
      (Canary_basic.step_dir_of_tag tag)
      file
  in
  try Some (Yojson.Basic.from_file path) with _ -> None

(** The language a step tag speaks for. A lib-side tag speaks for none,
    and the slots that resolve there ignore the parameter anyway. *)
let lang_of_tag ~(chain : Canary_basic.action list) (tag : string) :
    Canary_lang.lang =
  match Canary_basic.action_of_string tag with
  | Some
      ( Canary_basic.Build_binding l
      | Canary_basic.Probe_binding l
      | Canary_basic.Fetch (Canary_basic.Binding l)
      | Canary_basic.Build_app { lang = l } ) ->
      l
  | _ -> List.hd_exn (langs_of_chain chain)

(** WORST FIRST — the merge an agreement column needs when several
    methods, or several firing sites, report on one claim. The same
    ordering [evaluate_step] uses to merge evidence routes: a finding
    outranks a pass, and a pass outranks an undecided, so a cell can
    never lose a violation to a later [unavailable].

    [""] is NOT an outcome — it is the absence of one, and it ranks
    BELOW every real outcome including the undecided ones. Ranking it
    equal to [unavailable] (which it was, briefly) made a fold that
    never replaces its own initial value, so every rank-0 outcome read
    back as "not evaluated" — the one confusion this column exists to
    prevent. *)
let outcome_rank = function
  | "violated" -> 4
  | "error" -> 3
  | "inconclusive" -> 2
  | "holds" -> 1
  | "" -> -1
  | _ -> 0
  (* unavailable | undeclared | vacuous | not_implemented | not_applicable
     | disabled — every undecided outcome ranks alike, which is what stops
     a finding at one firing site being lost to a silence at another *)

(** A VERDICT IS A SYMBOL; A GAP IS A WORD (2026-09-15, user: "I am good
    to have hold/violated/(expected) error as symbols, but for the
    gapped cases, if we use the symbol, we need to explain them ahead;
    otherwise we can use simple english directly").

    Five distinct states used to render as one dot — [unavailable],
    [not_applicable], [not_implemented], [disabled] and "never recorded"
    were indistinguishable, so the table said "nothing here" where the
    honest answers were "nothing wrote the evidence", "your log is
    stale" and "this has never run cold". That is the same collapse the
    [2/3] cell had, one level down: the answer was always one hover
    away.

    Words rather than glyphs for the gaps, and the split is the
    semantics: a symbol means the check reached a verdict, a word means
    it did not. A reader can therefore tell a non-verdict from a verdict
    without consulting anything, which no pair of glyphs achieves. The
    key table glosses the four words anyway, since they are also the
    blame vocabulary.

    [·] stays a dot deliberately: "no run has recorded this cell" is a
    true ABSENCE, not a state the run reached. *)
let mark_of_outcome = function
  | "violated" | "error" -> "✗"
  | "holds" -> "✓"
  | "inconclusive" -> "no-ref"
  | "unavailable" -> "no-evid"
  (* THE TWO THE CAUSE SPLIT OUT (2026-09-15). All three used to be
     `unavailable`, so a cell that needed nothing read the same as one
     waiting on an inspector. `undeclared` is the project's to-do,
     `vacuous` is nobody's. *)
  | "undeclared" -> "no-decl"
  | "vacuous" -> "none"
  | "not_applicable" -> "stale"
  | "disabled" -> "off"
  | "not_implemented" -> "planned"
  | _ -> "·"

(** Is this mark a verdict the check actually reached? *)
let is_verdict = function "✓" | "✗" -> true | _ -> false

(* ── BLAME (2026-09-15, user) ──────────────────────────────────────

   A check column exists only when some method has an EVALUATOR and the
   project's declarations PERMIT it ([check_cols_of_chain]'s two
   filters). So every cell in an existing column is supposed to be
   decidable, and a cell that is not decided is a DEFECT rather than a
   legitimate blank. Naming which defect is what makes it countable,
   and countable is what tells you how eager to be.

   Four words, and they point at three different owners:

   - [evidence]   nothing wrote the inspection the method reads. The
                  WIRING is incomplete — an inspector is missing, or
                  the reader is ordered before the writer;
   - [declaration] the evidence was read and the project declared
                  nothing to compare it against. The SPEC is
                  incomplete;
   - [version]    the project declared ONE value where its own version
                  axis has several. Also the spec, but a different
                  repair, and it is the only blame that attaches to a
                  DECIDED cell — see below;
   - [stale]      the log predates the current registry. Nobody's
                  fault; re-run.

   WHY [version] ALSO BLAMES A ✗. sqlite's [declared_symbols_exported]
   is `violated` on its built-Stable worlds because the lib there is
   3.43.2, chosen as the last release BEFORE 3.44.0 added
   `sqlite3_get_clientdata`, while the project declares both clientdata
   symbols once for every version point. The agreement is right and the
   world is wrong on purpose; what is actually broken is that the
   declaration cannot say "these two symbols exist from 3.44". A red
   cell that may be the spec's fault rather than the world's has to say
   so, or the count of real findings is wrong.

   EVERY WORD IS A STATIC SCAN of the project spec plus the cell's
   recorded outcome. Nothing here waits on a fix, which is the property
   the request turned on. *)

(** How many distinct versions this project's worlds give an artifact of
    this kind. Read off the ENUMERATED worlds rather than the declared
    universe: the universe is what a project wrote down, the worlds are
    what the enumeration kept, and only the second is what a run can
    disagree about. One point = a genuinely thin axis (zarith's lib:
    apt already ships GMP's newest), so a single-valued declaration is
    exactly right there and must not be blamed. *)
let version_points_of_kind (scenarios : Canary_artifact.assignment list)
    (k : Canary_basic.artifact_kind) : int =
  List.concat_map scenarios ~f:(fun a ->
      List.filter_map a ~f:(fun (info, (pl : Canary_artifact.placement)) ->
          if Poly.equal (Canary_artifact.kind_of info) k then
            (* [string_of_build_id], not the bare [id]: an UNPINNED
               placement has [id = ""] ([Canary_basic.good]), so keying
               on the id alone collapsed sqlite's Built@Stable and
               Built@Dev into one point and no project was ever version-
               blind. The printed form falls back to the channel, which
               is the identity the enumeration actually ranges over. *)
            Some (Canary_basic.string_of_build_id pl.Canary_artifact.version)
          else None))
  |> List.dedup_and_sort ~compare:String.compare
  |> List.length

(** The artifact kinds a [Declared_facts] method of this agreement holds
    its declaration against — i.e. the kinds whose version axis decides
    whether the declaration is single-valued for a moving target. Empty
    when the agreement makes no declaration comparison at all, which is
    what makes a peer comparison unblameable on these grounds. *)
let declared_against ~(lang : Canary_lang.lang)
    ~(world : Canary_artifact.assignment)
    ~(an : Canary_project_analysis.t) (slug : string) :
    Canary_basic.artifact_kind list =
  match Canary_agreement.agreement_named slug with
  | None -> []
  | Some r ->
      List.concat_map r.Canary_agreement.ag.Canary_agreement_common.ag_methods
        ~f:(fun m ->
          match m.Canary_agreement_common.m_reference with
          | Canary_agreement_common.Declared_facts ->
              List.filter_map
                (m.Canary_agreement_common.m_inputs
                   { Canary_agreement_common.ac_mechanism =
                       Canary_project_analysis.mechanism_for an lang;
                     ac_lang = lang;
                     ac_world = world;
                     ac_declared = an.Canary_project_analysis.an_declared })
                ~f:(Canary_agreement_common.artifact_of_input ~lang)
          (* every other reference kind holds the artifact against
             something that is not a project declaration, so a
             single-valued declaration cannot be what is wrong *)
          | Canary_agreement_common.Artifact_itself
          | Canary_agreement_common.Peer_artifact
          | Canary_agreement_common.Sibling_world
          | Canary_agreement_common.Test_suite ->
              [])
      |> List.dedup_and_sort ~compare:Poly.compare

let blame_of ~(outcome : string) ~(is_declaration : bool)
    ~(version_blind : bool) : string option =
  match outcome with
  | "unavailable" -> Some "evidence"
  (* READ, NOT GUESSED (2026-09-15). These two used to arrive as
     `unavailable` and be blamed `evidence` with everything else, which
     is how sqlite's eight `declared_versions_exported` cells sat on a
     work queue for a defect the evaluator's own prose denied. The
     evaluator says which side was absent now, so this stops inferring. *)
  | "undeclared" -> Some "declaration"
  | "vacuous" -> Some "vacuous"
  | "inconclusive" ->
      (* AND HERE THE TWO REFERENCE KINDS PART WAYS. A DECLARATION
         comparison that reaches [inconclusive] found the declaration
         empty — the project did not say what it ships, which is a spec
         gap. A PEER comparison that reaches it read both artifacts and
         neither carried anything of this kind, which is a fact about
         the WORLD and nobody's fault: sqlite's libsqlite3 has no symbol
         versioning, so [required_versions_exported] has nothing to
         compare and never will. Counting that as a defect would put ten
         permanent rows on a work queue. *)
      Some
        (if not is_declaration then "vacuous"
         else if version_blind then "version"
         else "declaration")
  | "not_applicable" -> Some "stale"
  | "violated" | "error" -> if version_blind then Some "version" else None
  | _ -> None

(** What each blame word means, for the key table and the terminal
    legend. Kept beside {!blame_of} so a new word cannot ship unglossed.
    Ordered work-first: the last row is the one that asks nothing. *)
let blame_gloss : (string * string) list =
  [ ("evidence", "nothing wrote the inspection this reads — wiring");
    ("declaration", "read, but the project declared nothing to compare");
    ("version", "one declared value, several version points — spec");
    ("stale", "the log predates the registry — re-run");
    ("vacuous", "both sides read, neither has anything of this kind — fine") ]

(** ONE CELL, ONE CLAIM (2026-09-14, user). The cell used to aggregate
    every agreement slotted at a point and report [2/3] — which said
    how many had been decided and would not say which, so the answer
    was always one hover away and two rows could not be compared by
    eye. A column is one agreement at one slot now, and the cell is
    that agreement's outcome.

    [None] when the claim was never observed in any recorded run, which
    the caller renders as a dot: the column still exists, because its
    existence says the claim BELONGS here, and that is true whether or
    not anything has run. *)
let check_cell ~(chain : Canary_basic.action list)
    ~(obs : Canary_status.agreement_obs list)
    ~(world : Canary_artifact.assignment)
    ~(version_points : Canary_basic.artifact_kind -> int)
    ~(an : Canary_project_analysis.t) (a : Canary_basic.action)
    (s : Canary_agreement_common.stage) (slug : string) :
    cell * (Canary_basic.artifact_kind * string) list =
  (* THE LANGUAGE THIS COLUMN SPEAKS FOR — the one its action names,
     falling back to the chain's for a lib-side action that names
     none. Every question below that asks a method what it reads has to
     be asked in it. *)
  let lang =
    match a with
    | Canary_basic.Build_binding l
    | Canary_basic.Probe_binding l
    | Canary_basic.Build_app { lang = l } ->
        l
    | _ -> List.hd_exn (langs_of_chain chain)
  in
  (* an observation belongs to THIS column when its agreement slots
     here under the language its own step tag speaks for — the slot is
     where a claim is read, the tag is where it was evaluated, and for
     a consumer-side claim those differ by design *)
  let mine =
    List.filter obs ~f:(fun (o : Canary_status.agreement_obs) ->
        String.equal o.Canary_status.ao_agreement slug
        &&
        let lang = lang_of_tag ~chain o.Canary_status.ao_tag in
        match Canary_agreement.agreement_named slug with
        | None -> false
        | Some r -> (
            match
              Canary_agreement_common.slot_in_chain
                r.Canary_agreement.ag.Canary_agreement_common.ag_slot ~lang
                ~chain
            with
            | Some (a', s') -> Poly.equal a' a && Poly.equal s' s
            | None -> false))
  in
  (* worst of this claim's methods and firing sites — a finding cannot
     be lost to a later [unavailable] *)
  let outcome =
    List.fold mine ~init:"" ~f:(fun acc o ->
        if outcome_rank o.Canary_status.ao_outcome > outcome_rank acc then
          o.Canary_status.ao_outcome
        else acc)
  in
  (* IS THIS CLAIM HELD AGAINST A SINGLE-VALUED DECLARATION WHILE THE
     THING IT DESCRIBES MOVES? Static: it asks the registry what kind
     of comparison this is and the enumeration how many version points
     that artifact has. Neither question needs a run, which is why this
     can be attributed before it is fixed. *)
  let against = declared_against ~lang ~world ~an slug in
  let version_blind = List.exists against ~f:(fun k -> version_points k > 1) in
  let blame =
    blame_of ~outcome
      ~is_declaration:(not (List.is_empty against))
      ~version_blind
  in
  (* the observation that SUPPLIED the outcome: the MOST RECENT one
     reporting it, when several methods or firing sites agree. Its tag
     names the step in the tooltip and its timestamp is the cell's [at],
     so the two always describe the same line. Until 2026-09-23 the
     tooltip named the FIRST in list order — on zarith, an inspection
     step's [holds] from a run eighty minutes older than the probe that
     last confirmed it. The stamps sort as text because the log writes
     them fixed-width, most significant field first. *)
  let supplier =
    List.fold mine ~init:None ~f:(fun acc o ->
        if not (String.equal o.Canary_status.ao_outcome outcome) then acc
        else
          match acc with
          | Some p
            when String.( > ) p.Canary_status.ao_at o.Canary_status.ao_at ->
              acc
          | _ -> Some o)
  in
  let c =
    { mark = mark_of_outcome outcome;
      recorded =
        R_check (if String.is_empty outcome then None else Some outcome);
      at =
        Option.bind supplier ~f:(fun o ->
            if String.is_empty o.Canary_status.ao_at then None
            else Some o.Canary_status.ao_at);
      provision = "";
      blame;
      detail =
        Some
          (slug ^ ": "
          ^ (if String.is_empty outcome then
               "not evaluated in any recorded run"
             else
               (* the reason, where the log carried one — "unavailable"
                  alone never told anybody what was missing *)
               match supplier with
               | Some o ->
                   outcome ^ " (at " ^ o.Canary_status.ao_tag ^ ")"
               | None -> outcome)
          ^
          match blame with
          | None -> ""
          | Some b ->
              " — blame: " ^ b ^ " ("
              ^ Option.value
                  (List.Assoc.find blame_gloss b ~equal:String.equal)
                  ~default:""
              ^ ")") }
  in
  (* WHAT A VIOLATION WAS READING. Only a violation implicates: an
     [unavailable] read nothing and a [holds] found nothing wrong, so
     neither has an artifact to point at. *)
  let implicated =
    if not (String.equal outcome "violated") then []
    else
      match Canary_agreement.agreement_named slug with
      | None -> []
      | Some r ->
          List.concat_map
            r.Canary_agreement.ag.Canary_agreement_common.ag_methods
            ~f:(fun m ->
              List.filter_map
                (m.Canary_agreement_common.m_inputs
                   { Canary_agreement_common.ac_mechanism =
                       Canary_project_analysis.mechanism_for an lang;
                     ac_lang = lang;
                     ac_world = world;
                     ac_declared = an.Canary_project_analysis.an_declared })
                ~f:(fun i ->
                  Option.map
                    (Canary_agreement_common.artifact_of_input ~lang i)
                    ~f:(fun k -> (k, slug))))
          |> List.dedup_and_sort ~compare:Stdlib.compare
  in
  (c, implicated)

(* [?root] is where the run logs are read from — the default is the one
   every run writes. A pin passes a fixture tree, which is how the record
   export is checked against a log whose every line it wrote itself. *)
let matrix_of ?(root = "_out")
    (projects : (string * Canary_project_run.project_run) list) : t =
  let setting_cols = setting_columns_of projects in
  let cols =
    List.concat_map projects ~f:(fun (_, pr) ->
        let acts = Canary_project_run.covered_actions_of pr in
        let an = Canary_pipeline.analysed_of pr in
        (* one representative world for the SHAPE: which artifacts are
           inspectable is a property of the project's chain and its
           declarations, not of a particular scenario's placements *)
        let world =
          match Canary_project_run.scenarios_of pr with
          | w :: _ -> Some w
          | [] -> None
        in
        List.map acts ~f:(fun a -> Act a)
        @ check_cols_of_chain acts ~an
        @ (match world with
           | None -> []
           | Some w -> artifact_cols_of_chain acts ~world:w ~an))
    |> Stdlib.List.sort_uniq Stdlib.compare
    |> List.stable_sort ~compare:compare_col
  in
  let columns = List.map cols ~f:label_of_col in
  let rows =
    List.concat_map projects ~f:(fun (project, pr) ->
        let logs = Canary_status.project_log ~root ~project in
        (* the agreement half of the same log, read once per project *)
        let agmts = Canary_status.project_agreements ~root ~project in
        (* PASS 2's value, once per project. It carries what the project
           says it ships — the reference half of the declaration
           comparisons, needed here to ask a method what it reads — and
           the mechanism each language binds through, which is the half
           this file used to guess from the language. *)
        let an = Canary_pipeline.analysed_of pr in
        let platform = platform_label () in
        (* rows ordered by ref → c lib → bindings ({!row_key}) *)
        let scenarios =
          List.stable_sort (Canary_project_run.scenarios_of pr)
            ~compare:(fun x y -> Stdlib.compare (row_key pr x) (row_key pr y))
        in
        (* how far each artifact kind MOVES in this project, computed
           once per project rather than per cell — it is a property of
           the enumeration, and every row of the project shares it *)
        let version_points = version_points_of_kind scenarios in
        List.map scenarios ~f:(fun a ->
            (* the world's steps, derived ONCE: the chain the cells range
               over is their actions, and the record lists them all *)
            let world_steps = Canary_pipeline.display_steps_of pr a in
            let chain_acts = Canary_pipeline.actions_of_steps world_steps in
            let chain_tags =
              List.map chain_acts ~f:Canary_basic.string_of_action
            in
            let scenario =
              Stdlib.Filename.basename
                (Canary_project_run.scenario_dir_of ~pr_name:project a)
            in
            let sl = log_of_scenario ~scenario logs in
            let scenario_obs =
              match List.Assoc.find agmts scenario ~equal:String.equal with
              | Some o -> o
              | None -> []
            in
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
            (* the CHECK cells first, because a violation is what tells
               the setting block which artifact to flag — the answer
               runs backwards along the row, from the check that failed
               to the artifact it was reading *)
            let check_cells =
              List.filter_map cols ~f:(fun col ->
                  match col with
                  | Check (ca, cs, slug)
                    when List.mem chain_acts ca ~equal:Poly.equal ->
                      Some
                        ( label_of_col col,
                          check_cell ~chain:chain_acts ~obs:scenario_obs
                            ~world:a ~version_points ~an ca cs slug )
                  | _ -> None)
            in
            let implicated_kinds =
              List.concat_map check_cells ~f:(fun (_, (_, impl)) -> impl)
            in
            (* every step, each in its own log line's state — the
               siblings and inspections the cells have no column for *)
            let row_steps =
              List.map world_steps ~f:(fun (s : Canary_step_model.step) ->
                  let state, at, detail =
                    reading_of_run sl s.Canary_step_model.tag
                  in
                  { ws_tag = s.Canary_step_model.tag;
                    ws_action = s.Canary_step_model.action;
                    ws_location = s.Canary_step_model.location;
                    ws_inspects = s.Canary_step_model.inspects;
                    ws_dummy = s.Canary_step_model.dummy;
                    ws_place =
                      Canary_topology.place_step ~pr ~world:a
                        ~action:s.Canary_step_model.action
                        ~location:s.Canary_step_model.location
                        ~inspects:s.Canary_step_model.inspects
                        ~dummy:s.Canary_step_model.dummy;
                    ws_state = state;
                    ws_at = at;
                    ws_detail = detail })
            in
            (* THE JOIN'S RESULT (phase B2): each realized edge with the
               steps realizing it, and each placed claim with its
               outcomes here — so the overlay draws and computes nothing *)
            let row_edges =
              List.filter_map Canary_topology.edges ~f:(fun e ->
                  let tags =
                    List.filter_map row_steps ~f:(fun s ->
                        match s.ws_place with
                        | Canary_topology.On ids
                          when List.mem ids e.Canary_topology.eg_id
                                 ~equal:String.equal ->
                            Some s.ws_tag
                        | _ -> None)
                  in
                  if List.is_empty tags then None
                  else Some (e.Canary_topology.eg_id, tags))
            in
            let row_claims =
              List.filter_map Canary_topology.claim_sites ~f:(fun cs ->
                  let slug = cs.Canary_topology.cs_claim in
                  let outcomes =
                    List.filter_map cols ~f:(fun col ->
                        match col with
                        | Check (_, _, s) when String.equal s slug ->
                            Option.map
                              (List.Assoc.find check_cells (label_of_col col)
                                 ~equal:String.equal)
                              ~f:(fun ((c : cell), _) ->
                                ( label_of_col col,
                                  match c.recorded with
                                  | R_check o -> o
                                  | R_act _ | R_artifact -> None ))
                        | _ -> None)
                  in
                  if List.is_empty outcomes then None else Some (slug, outcomes))
            in
            { project;
              scenario;
              index = 0;
              code = "";
              ref_label;
              ref_url;
              platform;
              recorded_on =
                Option.value_map sl ~default:[]
                  ~f:(fun (sl : Canary_status.scenario_log) ->
                    sl.Canary_status.sl_platforms);
              steps = row_steps;
              edges = row_edges;
              claims = row_claims;
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
                                    ^ r.Canary_artifact_source.ref_);
                              (* every check in this row that failed
                                 while reading THIS artifact *)
                              implicated =
                                (match
                                   List.filter_map implicated_kinds
                                     ~f:(fun (k, slug) ->
                                       if Poly.equal k kind then Some slug
                                       else None)
                                   |> List.dedup_and_sort
                                        ~compare:String.compare
                                 with
                                 | [] -> None
                                 | slugs ->
                                     Some (String.concat ~sep:", " slugs)) } ));
              cells =
                List.map cols ~f:(fun col ->
                  let tag = label_of_col col in
                  match col with
                  | Artifact aa ->
                      (* what this step left behind, read off the
                         inspection it wrote. No cell where the action
                         is not in this row's chain, and none where it
                         ran but recorded nothing — an artifact column
                         with no summary has nothing to say, and the
                         renderers drop a column no row fills. *)
                      ( tag,
                        if not (List.mem chain_acts aa ~equal:Poly.equal) then
                          None
                        else
                          Option.bind
                            (inspection_of_step ~root ~project ~scenario
                               (Canary_basic.string_of_action aa))
                            ~f:(fun j ->
                              Option.map (summarize_inspection j) ~f:(fun s ->
                                  let kinds =
                                    Canary_action.produces_of_action aa
                                  in
                                  let blamed =
                                    List.filter_map implicated_kinds
                                      ~f:(fun (k, slug) ->
                                        if
                                          List.mem kinds k ~equal:Poly.equal
                                        then Some slug
                                        else None)
                                    |> List.dedup_and_sort
                                         ~compare:String.compare
                                  in
                                  { mark = s;
                                    recorded = R_artifact;
                                    at = None;
                                    provision = "";
                                    blame = None;
                                    detail =
                                      (match blamed with
                                       | [] -> None
                                       | bs ->
                                           Some
                                             ("implicated by "
                                            ^ String.concat ~sep:", " bs)) })) )
                  | Check _ ->
                      (* computed above, because the settings needed
                         the violations first. A check column belongs
                         to this row only when the row's own chain
                         offers the slot — a project that fetches its
                         binding has no build_binding_ocaml_pre, and
                         the renderers drop a column no row fills *)
                      ( tag,
                        Option.map
                          (List.Assoc.find check_cells tag
                             ~equal:String.equal)
                          ~f:fst )
                  | Act _ ->
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
                      let state, at, detail = reading_of_run sl tag in
                      ( tag,
                        Some
                          { mark = Canary_status.mark_of_state state;
                            recorded = R_act state;
                            at;
                            provision;
                            blame = None;
                            detail } )
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
  let check_columns =
    List.filter_map cols ~f:(function
      | Check _ as c -> Some (label_of_col c)
      | Act _ | Artifact _ -> None)
  in
  let artifact_columns =
    List.filter_map cols ~f:(function
      | Artifact _ as c -> Some (label_of_col c)
      | Act _ | Check _ -> None)
  in
  { setting_columns = List.map setting_cols ~f:fst; columns;
    typed_columns = cols; check_columns; artifact_columns; rows }

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
           (* a check column is rendered by its STAGE alone: it is
              always adjacent to the action it names, so repeating
              [probe_binding_python] in the header buys nothing and
              costs 20 columns of width *)
           (* A CHECK column is one agreement, and its full label
              ([probe_binding_ocaml_pre:required_symbols_exported]) is
              far too wide for a terminal. The action is adjacent, so
              the header carries the STAGE and the agreement's
              initials: »pre·rse. The initials are unique across the
              thirteen, and the legend below names them. *)
           (* the terminal drops only the ACTION half — it is the
              column immediately to the left — and keeps the code, which
              is already the name *)
           let header tag =
             if List.mem m.check_columns tag ~equal:String.equal then
               match String.lsplit2 tag ~on:':' with
               | Some (slot, code) ->
                   (if String.is_suffix slot ~suffix:"_post" then "»" else "›")
                   ^ code
               | None -> tag
             else if List.mem m.artifact_columns tag ~equal:String.equal then
               match String.lsplit2 tag ~on:'=' with
               | Some (_, kind) -> "=" ^ kind
               | None -> tag
             else tag
           in
           (* GROUP BY ACTION (2026-09-14, user). A row is
              [›pre … action …=out …»post] repeated, and with nothing
              between groups the eye cannot tell where one action's
              columns stop. A bar before each action's leading column
              is the same device the setting block already uses to
              separate the world from the run. *)
           let group_of tag =
             if List.mem m.check_columns tag ~equal:String.equal then
               Option.value_map (String.lsplit2 tag ~on:':') ~default:tag
                 ~f:(fun (slot, _) ->
                   Option.value
                     (String.chop_suffix slot ~suffix:"_post")
                     ~default:
                       (Option.value
                          (String.chop_suffix slot ~suffix:"_pre")
                          ~default:slot))
             else if List.mem m.artifact_columns tag ~equal:String.equal then
               Option.value_map (String.lsplit2 tag ~on:'=') ~default:tag ~f:fst
             else tag
           in
           let with_bars f =
             let _, out =
               List.fold used ~init:(None, []) ~f:(fun (prev, acc) tag ->
                   let g = group_of tag in
                   let sep =
                     match prev with
                     | Some p when not (String.equal p g) -> [ "| " ]
                     | _ -> []
                   in
                   (Some g, acc @ sep @ [ f tag ]))
             in
             String.concat ~sep:"" out
           in
           Fmt.pr "@.%s — %d scenario(s)@." r.project (List.length group);
           Fmt.pr "  %s%s| %s@." (pad "#")
             (String.concat ~sep:"" (List.map set_used ~f:pad))
             (with_bars (fun t -> pad (header t)));
           List.iter group ~f:(fun (rr : row) ->
               let cells =
                 with_bars (fun tag ->
                     match
                       List.Assoc.find rr.cells tag ~equal:String.equal
                     with
                     (* an artifact a failing check read: marked, not
                        coloured, because the terminal has no red *)
                     | Some (Some c)
                       when List.mem m.artifact_columns tag ~equal:String.equal
                            && Option.is_some c.detail ->
                         pad (fit ("!" ^ c.mark))
                     | Some (Some c) -> pad c.mark
                     | Some None -> pad ""
                     | None -> pad "")
               in
               let sets =
                 List.map set_used ~f:(fun label ->
                     match
                       List.Assoc.find rr.settings label ~equal:String.equal
                     with
                     (* the terminal has no red, so an implicated
                        artifact is marked rather than coloured — the
                        same information, in the medium that carries *)
                     | Some (Some s) when Option.is_some s.implicated ->
                         pad ("!" ^ fit s.text)
                     | Some (Some s) -> pad (fit s.text)
                     | _ -> pad "—")
               in
               (* the global row index: "#N" for fast pointing; the
                  stable code is the historical pointer (see {!row.code}) *)
               Fmt.pr "  %s%s| %s@."
                 (pad (Printf.sprintf "#%d" rr.index))
                 (String.concat ~sep:"" sets)
                 cells)));
  let total = List.length m.rows in
  Fmt.pr "@.legend: ✓ done · not run ⊘ blocked xfail[cN] expected failure (cN confirming contracts) ✗ failed@.";
  (* the CHECK legend, printed only when there are check columns to
     explain. The initials are unambiguous but not guessable, and a
     three-letter column head with no key is a puzzle rather than a
     table. [›] is a requirement the next action depends on, [»] a
     verdict on what the last one made, [=] the artifact itself. *)
  (if not (List.is_empty m.check_columns) then
     let seen =
       List.filter_map m.check_columns ~f:(fun c ->
           Option.map (String.lsplit2 c ~on:':') ~f:snd)
       |> List.dedup_and_sort ~compare:String.compare
     in
     Fmt.pr
       "checks: › needed before the action  » verdict on what it made  = the \
        artifact@.        %s@."
       (String.concat ~sep:"  "
          (List.filter_map (Canary_agreement.summary_rows ()) ~f:(fun r ->
               if
                 List.mem seen r.Canary_agreement.sr_code ~equal:String.equal
               then
                 Some
                   (r.Canary_agreement.sr_code ^ " "
                  ^ r.Canary_agreement.sr_slug)
               else None))));
  (* AND WHAT A NON-VERDICT CELL SAYS. A symbol means the check reached
     a verdict, a word means it did not — the words are meant to read
     without a key, but [no-ref] is the one that does not quite, so the
     whole set is glossed rather than the odd one out. *)
  (if
     List.exists m.rows ~f:(fun (r : row) ->
         List.exists r.cells ~f:(function
           | _, Some c -> not (is_verdict c.mark || String.equal c.mark "·")
           | _ -> false))
   then
     Fmt.pr
       "        no-evid nothing wrote the evidence  no-decl the project \
        declared nothing  none nothing of this kind here@.        \
        no-ref nothing to compare against  stale log predates the \
        registry  off disabled@.");
  (* THE GAP, COUNTED (2026-09-15, user). A check column exists only
     where the claim CAN be decided, so every non-verdict cell in one is
     a defect rather than a blank — and the blame says whose. Printed
     only when there is a gap, because a clean table should not carry a
     paragraph explaining an empty set. *)
  (let counts : (string, int) Hashtbl.t = Hashtbl.create (module String) in
   List.iter m.rows ~f:(fun (r : row) ->
       List.iter r.cells ~f:(fun (_, cell) ->
           match cell with
           | Some { blame = Some b; _ } ->
               Hashtbl.update counts b ~f:(function None -> 1 | Some n -> n + 1)
           | _ -> ()));
   let rows =
     Hashtbl.to_alist counts
     |> List.sort ~compare:(fun (_, a) (_, b) -> Int.compare b a)
   in
   if not (List.is_empty rows) then begin
     Fmt.pr "@.gap: %s@."
       (String.concat ~sep:"  "
          (List.map rows ~f:(fun (b, n) -> Printf.sprintf "%d %s" n b)));
     List.iter blame_gloss ~f:(fun (w, g) ->
         if List.Assoc.mem rows w ~equal:String.equal then
           Fmt.pr "     %-12s %s@." w g)
   end);
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

(* ── JSON — THE RUN RECORD (2026-09-23, status.md §2.7 phase A) ──

   What a program reads to draw a recorded run — first the overview's
   case diagrams — rather than what a person scans. So it carries the
   typed values the marks are rendered from: each column as its action,
   slot and agreement instead of a label to parse; each action cell's
   step STATE (ran / warm / blocked / unrecorded) and verdict, because a
   warm ✓ re-checked nothing; each check cell's outcome label, because
   [violated] and [error] share a ✗; WHEN the log recorded each cell;
   and the platform the run LOGGED, not the one reading it.

   The mark stays in every cell, so a consumer that wants the table's
   glyph does not re-derive it. A cell NOT in the world's chain has no
   key at all — which is what lets a diagram grey out an edge that does
   not exist in this world without being told.

   ⚠ One field is not the run's: a system package's version inside a
   SETTING is asked of the machine rendering the record
   ({!sys_pkg_version}) unless the spec pins it. The run never recorded
   it (§2.7 finding 2); phase E is where it will. *)

let json_of_col (c : col) : Yojson.Basic.t =
  let head kind a =
    [ ("label", `String (label_of_col c));
      ("kind", `String kind);
      ("action", `String (Canary_basic.string_of_action a)) ]
  in
  match c with
  | Act a -> `Assoc (head "action" a)
  | Check (a, s, slug) ->
      `Assoc
        (head "check" a
        @ [ ("stage", `String (Canary_agreement_common.string_of_stage s));
            ("agreement", `String slug);
            ("code", `String (Canary_agreement_common.short_code_of_slug slug))
          ])
  | Artifact a ->
      `Assoc (head "artifact" a @ [ ("artifact", `String (produced_label a)) ])

(* A step state's fields — ONE spelling, shared by an action cell and a
   world step, so the two halves of the record cannot disagree about
   what [warm] or an attributed [xfail] looks like. *)
let state_fields (st : Canary_status.step_state) : (string * Yojson.Basic.t) list
    =
  ("state", `String (Canary_status.string_of_step_state st))
  ::
  (match st with
   | Canary_status.Ran v | Canary_status.Warm v -> (
       ("verdict", `String (Canary_status.string_of_verdict v))
       ::
       (match v with
        | Canary_status.Xfail (_ :: _ as names) ->
            [ ("agreements", `List (List.map names ~f:(fun n -> `String n))) ]
        | _ -> []))
   | Canary_status.Blocked | Canary_status.Unrecorded -> [])

let json_of_cell (c : cell) : Yojson.Basic.t =
  let opt key = function Some s -> [ (key, `String s) ] | None -> [] in
  let reading =
    match c.recorded with
    | R_act st -> state_fields st
    | R_check o ->
        [ ("outcome", match o with Some s -> `String s | None -> `Null) ]
    | R_artifact -> []
  in
  `Assoc
    ((("mark", `String c.mark) :: reading)
    @ opt "at" c.at
    @ (if String.is_empty c.provision then []
       else [ ("provision", `String c.provision) ])
    @ opt "detail" c.detail @ opt "blame" c.blame)

(* A step keeps its TAG — the log's key, and what tells two probes of one
   action apart — beside its typed action. The location is spelled by
   [Canary_store.string_of_location]: [build_tree], [staged],
   [sys_pm:apt], [ocaml:opam]. *)
(* where a step sits: the edges it realizes, the step it is evidence
   for, or the reason it has none — a stable code and its sentence *)
let json_of_place : Canary_topology.place -> Yojson.Basic.t = function
  | Canary_topology.On ids -> `Assoc [ ("on", `List (List.map ids ~f:(fun i -> `String i))) ]
  | Canary_topology.Evidence_for p -> `Assoc [ ("evidence_for", `String p) ]
  | Canary_topology.Unplaced u ->
      `Assoc
        [ ("unplaced", `String (Canary_topology.code_of_unplaced u));
          ("why", `String (Canary_topology.string_of_unplaced u)) ]

let json_of_world_step (s : world_step) : Yojson.Basic.t =
  let opt key = function Some v -> [ (key, `String v) ] | None -> [] in
  `Assoc
    ([ ("tag", `String s.ws_tag);
       ("action", `String (Canary_basic.string_of_action s.ws_action)) ]
    @ opt "location" (Option.map s.ws_location ~f:Canary_store.string_of_location)
    @ opt "inspects" s.ws_inspects
    @ opt "dummy" s.ws_dummy
    @ [ ("place", json_of_place s.ws_place) ]
    @ state_fields s.ws_state
    @ opt "at" s.ws_at @ opt "detail" s.ws_detail)

let to_json (m : t) : Yojson.Basic.t =
  `Assoc
    [ ( "setting_columns",
        `List (List.map m.setting_columns ~f:(fun c -> `String c)) );
      ("columns", `List (List.map m.typed_columns ~f:json_of_col));
      ( "rows",
        `List
          (List.map m.rows ~f:(fun (r : row) ->
               `Assoc
                 [ ("project", `String r.project);
                   ("scenario", `String r.scenario);
                   ("index", `Int r.index);
                   ("code", `String r.code);
                   ( "recorded_on",
                     `List (List.map r.recorded_on ~f:(fun p -> `String p)) );
                   ( "settings",
                     `Assoc
                       (List.filter_map r.settings ~f:(fun (label, s) ->
                            match s with
                            | Some s -> Some (label, `String s.text)
                            | None -> None)) );
                   ( "cells",
                     `Assoc
                       (List.filter_map r.cells ~f:(fun (tag, c) ->
                            Option.map c ~f:(fun c -> (tag, json_of_cell c))))
                   );
                   ("steps", `List (List.map r.steps ~f:json_of_world_step));
                   ( "edges",
                     `Assoc
                       (List.map r.edges ~f:(fun (id, tags) ->
                            (id, `List (List.map tags ~f:(fun t -> `String t)))))
                   );
                   ( "claims",
                     `Assoc
                       (List.map r.claims ~f:(fun (slug, outcomes) ->
                            ( slug,
                              `List
                                (List.map outcomes ~f:(fun (column, o) ->
                                     `Assoc
                                       [ ("column", `String column);
                                         ( "outcome",
                                           match o with
                                           | Some s -> `String s
                                           | None -> `Null ) ])) ))) )
                 ])) ) ]

(** THE RECORD AS PRINTED — what [canary result --json] writes to stdout,
    and ALL it writes (§2.7 finding 1: the page notice used to follow it,
    and the output did not parse). A function rather than a line in the
    command so a pin can parse exactly the text a consumer receives. *)
let json_export (m : t) : string =
  Yojson.Basic.pretty_to_string (to_json m) ^ "\n"

(* ── HTML (the web page) ── *)

(** Self-contained page: the full union-column table — project | ref
    (linked to the remote commit/tree) | platform | actions — colored
    cells showing the provision choice + the verdict. The long
    scenario ids live in the cell tooltips. The styling mirrors
    {!Canary_html}'s badge tones without importing its machinery. *)
(** Returns [(agreement_overview, result_page)] (2026-09-23, user: the
    agreement table moves to the methodology page).

    A PAIR RATHER THAN A MOVE. The overview is ~250 lines of rendering
    built from the registry, and lifting it into another module means
    retyping it — which CLAUDE.md is explicit about being the expensive
    kind of edit, and it would have bought nothing: the block is already
    one self-contained string. So it is computed here as before and
    RETURNED, and the two pages each embed it or not.

    ⚠ The overview is NOT pure mechanism, which is why moving it needed
    a decision rather than a cut. Its last two columns — `decided` and
    `blame` — are counted from recorded runs, per agreement. So the page
    that receives it inherits a dependency on run state, and says so;
    the alternative was to split the table at that seam and show a
    reader two halves of one row in two places. *)
let render_parts (m : t) ~(generated_at : string) : string * string =
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
  (* THE CHECK KEY — the same rows the generated catalogue prints
     (2026-09-14, user: "we can just use the same table in both the doc
     and the html"). The page's check columns are headed by three-letter
     codes, which are compact and not guessable, so the page has to
     carry its own key; taking it from [Canary_agreement.summary_rows]
     rather than restating it is what stops the two from drifting.

     ALWAYS VISIBLE (2026-09-14, user). It was behind a disclosure
     first, on the theory that a key is for a reader who meets an
     unfamiliar code. That was wrong the moment the code became the
     column's only name: the table is unreadable without it, so hiding
     it behind a click hides the table. *)
  (* GROUPED BY ACTION, as the terminal view is: a rule down the left
     edge of each action's first column, so a reader can see where one
     action's pre-checks, run, result and verdicts begin and end. *)
  let group_of c =
    if List.mem m.check_columns c ~equal:String.equal then
      Option.value_map (String.lsplit2 c ~on:':') ~default:c ~f:(fun (slot, _) ->
          Option.value
            (String.chop_suffix slot ~suffix:"_post")
            ~default:
              (Option.value (String.chop_suffix slot ~suffix:"_pre")
                 ~default:slot))
    else if List.mem m.artifact_columns c ~equal:String.equal then
      Option.value_map (String.lsplit2 c ~on:'=') ~default:c ~f:fst
    else c
  in
  let group_starts =
    let _, acc =
      List.fold m.columns ~init:(None, []) ~f:(fun (prev, acc) c ->
          let g = group_of c in
          let starts =
            match prev with Some p -> not (String.equal p g) | None -> true
          in
          (Some g, if starts then c :: acc else acc))
    in
    acc
  in
  let is_group_start c = List.mem group_starts c ~equal:String.equal in
  (* THE TALLIES, hoisted out of the retired check-key table
     (2026-09-17). Counted from the RENDERED cells rather than re-read
     from the logs, so a key cannot disagree with the table it explains:
     if a reader can see eight ticks in the [dse] column, the tally says
     eight. The agreement overview carries them now — see below for why there
     is no longer a separate key. *)
  let tally code =
    let held = ref 0 and broke = ref 0 in
    List.iter m.rows ~f:(fun (rr : row) ->
        List.iter rr.cells ~f:(fun (tag, cell) ->
            match (String.lsplit2 tag ~on:':', cell) with
            | Some (_, c), Some cc when String.equal c code ->
                if String.equal cc.mark "✓" then Int.incr held
                else if String.equal cc.mark "✗" then Int.incr broke
            | _ -> ()));
    match (!held, !broke) with
    | 0, 0 -> "<span class=\"kq\">not decided in any row</span>"
    | h, 0 -> Printf.sprintf "%d ✓" h
    | 0, b -> Printf.sprintf "%d ✗" b
    | h, b -> Printf.sprintf "%d ✓ · %d ✗" h b
  in
  (* AND WHAT THOSE ROWS BLAME (2026-09-15, user: "before we fix that,
     can we attribute it as one thing to blame in the table, so we can
     see how eager we need to fix it").

     Counted off the same rendered cells as [tally], for the same
     reason: a key that re-derived its numbers could disagree with the
     table it explains. A blank cell here means this agreement's rows
     are all fine — which is the only row of the key a reader can skip. *)
  let blame_tally code =
    let counts : (string, int) Hashtbl.t = Hashtbl.create (module String) in
    List.iter m.rows ~f:(fun (rr : row) ->
        List.iter rr.cells ~f:(fun (tag, cell) ->
            match (String.lsplit2 tag ~on:':', cell) with
            | Some (_, c), Some cc when String.equal c code -> (
                match cc.blame with
                | None -> ()
                | Some b ->
                    Hashtbl.update counts b ~f:(function
                      | None -> 1
                      | Some n -> n + 1))
            | _ -> ()));
    Hashtbl.to_alist counts
    |> List.sort ~compare:(fun (_, a) (_, b) -> Int.compare b a)
    |> List.map ~f:(fun (b, n) ->
           Printf.sprintf "<span title=\"%s\">%d %s</span>" (esc
             (Option.value
                (List.Assoc.find blame_gloss b ~equal:String.equal)
                ~default:""))
             n (esc b))
    |> String.concat ~sep:" · "
  in
  let recovery_grid =
    let module CR = Canary_agreement in
    let rows = CR.overview_rows () in
    let cols = CR.overview_columns () in
    let cell_class = function
      | CR.Rooted_and_detected -> "rd"
      | CR.Rooted -> "rr"
      | CR.Detected -> "dd"
      | CR.Nothing_here -> "nn"
    in
    let cell_text = function
      | CR.Rooted_and_detected -> "R+D"
      | CR.Rooted -> "R"
      | CR.Detected -> "D"
      | CR.Nothing_here -> ""
    in
    (* the ROOTING detail, keyed by slug — tool and artifact are prose
       and belong on the R cell as a tooltip rather than as two more
       columns of a table that is already wide *)
    let rooting =
      List.map (CR.summary_rows ()) ~f:(fun sr -> (sr.CR.sr_slug, sr))
    in
    (* THE VERDICT AND THE VOCABULARY, BOTH BEFORE THE DATA (2026-09-21,
       user). The harness printed only in the terminal, so this page —
       the view the table is actually read in — never said whether the
       table had been checked. And `kind` is the one column a reader has
       no prior vocabulary for, so it is glossed here rather than three
       screens down among the marks. *)
    (let v = CR.overview_verdict () in
     let bad =
       String.is_substring v ~substring:"VIOLATION"
       || String.is_substring v ~substring:"UNWATCHED"
     in
     Printf.sprintf "<p class=\"verdict%s\">%s</p>"
       (if bad then " bad" else "")
       (esc v))
    ^ "<dl class=\"legend\">"
    ^ "<dt>row order</dt><dd>trigger action, then agreement, then language, \
       then mechanism — so a claim's mechanisms sit together. \
       Unimplemented claims sort last.</dd>"
    ^ "<dt>code</dt><dd>the AGREEMENT's identity, so a repeated code is one \
       claim with several patterns, shown adjacent. It is the key to the \
       result matrix's check-column headings.</dd>"
    ^ "<dt>one row per pattern</dt><dd>a claim whose firing differs between \
       mechanisms gets a row each; a uniform claim stays one row and says \
       so by leaving <b>mech</b> empty.</dd>"
    ^ "<dt>&#9635;</dt><dd>an ARTIFACT the claim ranges over — its target. \
       A declaration is not an artifact, which is why some claims show \
       one.</dd>"
    ^ "<dt>R &middot; D &middot; R+D</dt><dd>R = the action whose rule RAN \
       (hover for the tool and the artifact); D = a method FIRES here; R+D \
       = both. A row with no R roots in no action of this graph.</dd>"
    ^ "<dt>implemented at</dt><dd><code>&lt;module&gt;&middot;&lt;function&gt;</code> \
       — the EVALUATOR, in \
       <code>src/canary/agreement/canary_agreement_&lt;module&gt;.ml</code>. \
       A RED cell means this check DOES NOT RUN here, and the cell says \
       which of the two reasons: <code>&lt;module&gt;&middot;&mdash;</code> \
       is a claim of ours with no evaluator, naming the file it would go \
       in; an ITALIC tool name is an existing tool we name but never \
       invoke. The tooltip also names where the agreement's METADATA is \
       declared; both are derived, neither stored.</dd>"
    ^ "<dt><code>_ext</code> rows</dt><dd>an EXISTING TOOL that answers the \
       same claim — same kind, same targets, same rooting, because it is \
       the same question. The code carries <code>*</code>; \
       <b>lang</b>/<b>object</b> state the TOOL's reach, not the claim's; \
       <b>decided</b> and <b>blame</b> are empty because nothing here has \
       run it. One row per (tool × claim), so a tool answering two claims \
       appears twice — the duplication IS that fact. Hover for what it \
       does BEYOND our claim.</dd>"
    ^ "<dt>lang &middot; mech &middot; object</dt><dd>an EMPTY cell means \
       that axis does not narrow the claim — every modelled language, \
       every mechanism of this row's language, or every object format. A \
       value appears only where the row is a strict subset; \
       <code>none</code> in lang and mech means no mechanism carries this \
       at all.</dd>"
    ^ "<dt>lag</dt><dd>action columns from the root to the nearest firing. \
       NOT the distance between the two SIDES of a comparison, which is a \
       different measure.</dd>"
    (* `kind` is the one column with no prior vocabulary, so it gets the
       glossary immediately above the table rather than a line here. A
       pointer, so the legend is still a complete list of columns. *)
    ^ "<dt>kind</dt><dd>what the claim ASSERTS — the six values are \
       glossed just below, next to the table that uses them.</dd>"
    ^ "</dl>"
    ^ "<p class=\"kq\">Why the table is shaped this way — the row-order \
       key, why a code repeats, why an empty cell is the right notation, \
       and why the rooting is re-languaged per row — is \
       <code>doc/canary/design/matrix.md</code>. \
       One note that belongs here because it misleads in the cell: \
       <code>soname</code> is an ELF word for a format-neutral fact, the \
       library's own recorded identity — <code>DT_SONAME</code> on ELF and \
       the <code>LC_ID_DYLIB</code> install name on Mach-O, which the \
       inspector writes into one field. Those claims are NOT elf-only; the \
       two version-node ones are.</p>"
    ^ "<p class=\"kq\">blame: "
    ^ String.concat ~sep:" &middot; "
        (List.map blame_gloss ~f:(fun (w, g) ->
             "<b>" ^ esc w ^ "</b> " ^ esc g))
    ^ "</p>"
    ^ "<div class=\"kinds\"><b>kind</b> — what the claim ASSERTS; not what \
       it is held against (the record's <code>against</code>), and not \
       whose rule it recovers (the <b>R</b> column)."
    ^ "<dl>"
    ^ "<dt>admissibility</dt><dd>would ONE action have accepted these \
       artifacts together as its inputs? <code>theory.md</code> §2's \
       <code>R_A</code>, the tuples a rule accepts.</dd>"
    ^ "<dt>promise</dt><dd>is this ONE artifact what its own producer said \
       it would be? Nothing is matched.</dd>"
    ^ "<dt>quality</dt><dd>is it sound on its own terms, whatever it is \
       paired with? No second side at all — and NO agreement yet.</dd>"
    ^ "<dt>preservation</dt><dd>still the same thing after a \
       transformation — two COPIES of one artifact, so no disagreement \
       between distinct components can violate it.</dd>"
    ^ "<dt>behaviour</dt><dd>does running it produce what was specified? \
       The only kind whose evidence is an execution.</dd>"
    ^ "<dt>composition</dt><dd>a verdict over other verdicts.</dd>"
    ^ "</dl><p class=\"kq\"><code>api_names_present</code> is an \
       ADMISSIBILITY claim one of whose members is a DECLARATION — the \
       watchlist stands in for the application's uses. Naming the evidence \
       is not the same as naming the claim, which is why <b>kind</b> and \
       the record's <code>against</code> are two fields.</p></div>"
    ^ "<table class=\"keytbl grid\"><thead><tr><th>code</th><th>agreement</th>\
     <th>kind</th><th>implemented at</th><th>lang</th><th>mech</th>\
     <th>object</th>"
    ^ String.concat ~sep:""
        (List.map CR.overview_artifact_columns ~f:(fun k ->
             "<th class=\"seth\">" ^ esc (CR.artifact_col_label k) ^ "</th>"))
    ^ String.concat ~sep:""
        (List.map cols ~f:(fun a ->
             "<th class=\"gcol\">" ^ esc (Canary_basic.string_of_action a)
             ^ "</th>"))
    ^ "<th>lag</th><th>decided</th><th>blame</th></tr></thead><tbody>"
    ^ String.concat ~sep:""
        (List.map rows ~f:(fun (row : CR.overview_row) ->
             let r = row.CR.ov_agreement in
             (* AN EXTERNAL ROW is the same claim as answered by an
                existing tool: same kind, same targets, same rooting,
                and a `*` on the code so the pair reads as one claim
                with two answerers. *)
             let ext = row.CR.ov_external in
             let code =
               Canary_agreement_common.short_code_of_slug r.CR.ag_slug
               ^ (match ext with None -> "" | Some _ -> "*")
             in
             let sr = List.Assoc.find rooting r.CR.ag_slug ~equal:String.equal in
             let root_title =
               match sr with
               | Some x when not (String.is_empty x.CR.sr_tool) ->
                   Printf.sprintf " title=\"%s — over %s\"" (esc x.CR.sr_tool)
                     (esc x.CR.sr_artifact)
               | _ -> ""
             in
             (* WHERE THE CODE IS. A missing evaluator is a RED cell
                naming the file it would go in, not a blank: the whole
                point of the column is that "planned" should read as a
                location rather than as a status word. *)
             let family, fn = CR.impl_of r in
             let impl_cell =
               match fn with
               | Some f ->
                   (* the tooltip names BOTH halves of "where the code
                      is": the record that DECLARES this agreement —
                      kind, rooting, methods — and the evaluator the
                      cell shows. Both are derived, neither is stored:
                      the declaration is `let <slug> : agreement` in the
                      family file, pinned by
                      `agreements.metadata_is_declared_under_its_slug`. *)
                   Printf.sprintf
                     "<td class=\"impl\" title=\"declared at %s, as `let %s \
                      : agreement`; evaluator %s\"><span \
                      class=\"kq\">%s&middot;</span>%s</td>"
                     (esc (CR.family_file_of r.CR.ag_id))
                     (esc r.CR.ag_slug) (esc f)
                     (esc family) (esc f)
               | None ->
                   Printf.sprintf
                     "<td class=\"impl none\" title=\"declared at %s, as \
                      `let %s : agreement` — but NO evaluator yet; it would \
                      go in the same file\"><span \
                      class=\"kq\">%s&middot;</span>&mdash;</td>"
                     (esc (CR.family_file_of r.CR.ag_id))
                     (esc r.CR.ag_slug) (esc family)
             in
             let impl_cell =
               match ext with
               | None -> impl_cell
               | Some x ->
                   Printf.sprintf
                     "<td class=\"impl ext\" title=\"%s — %s\">%s</td>"
                     (esc x.CR.xc_what) (esc x.CR.xc_beyond) (esc x.CR.xc_tool)
             in
             "<tr class=\"" ^ (match ext with None -> "" | Some _ -> "extrow")
             ^ "\"><td class=\"kc\">" ^ esc code ^ "</td><td>"
             ^ esc (CR.row_slug row) ^ "</td><td class=\"kind\">"
             ^ esc (CR.kind_label r)
             ^ "</td>" ^ impl_cell ^ "<td class=\"lm\">"
             (* the axis cells state THIS ROW's reach — the claim's for
                ours, the tool's for an external row. They used to
                inherit the claim's in both cases, which said something
                false about every tool. *)
             ^ esc (CR.row_lang_label row)
             ^ "</td><td class=\"lm\">"
             ^ esc (CR.row_mech_label row)
             ^ "</td><td class=\"mk\">" ^ esc (CR.row_format_label row) ^ "</td>"
             (* the TARGET artifacts — what the claim ranges over *)
             ^ String.concat ~sep:""
                 (List.map CR.overview_artifact_columns ~f:(fun k ->
                      if
                        List.mem row.CR.ov_reads k ~equal:Poly.equal
                      then "<td class=\"g tgt\">&#9635;</td>"
                      else "<td class=\"g nn\"></td>"))
             ^ String.concat ~sep:""
                 (List.map row.CR.ov_cells ~f:(fun (_, mk) ->
                      let t =
                        match mk with
                        | CR.Rooted | CR.Rooted_and_detected -> root_title
                        | _ -> ""
                      in
                      Printf.sprintf "<td class=\"g %s\"%s>%s</td>"
                        (cell_class mk) t (cell_text mk)))
             ^ "<td>"
             ^ (match CR.row_lag row with
                | Some d -> Int.to_string d
                | None -> "<span class=\"kq\">—</span>")
             (* decided / blame are facts about what OUR runs recorded,
                so an external row leaves them empty rather than
                borrowing the claim's — nothing here has run a tool. *)
             ^ "</td><td>"
             ^ (match ext with
                | None -> tally (Canary_agreement_common.short_code_of_slug r.CR.ag_slug)
                | Some _ -> "<span class=\"kq\">—</span>")
             ^ "</td><td>"
             ^ (match ext with
                | None -> blame_tally (Canary_agreement_common.short_code_of_slug r.CR.ag_slug)
                | Some _ -> "")
             ^ "</td></tr>"))
    ^ "</tbody></table>"
    (* THE LEGEND IS A LIST, NOT A PARAGRAPH (2026-09-21, user: "very
       verbose and no line break"). It had grown into a 79-line run-on
       by accretion — every column added its explanation to the end of
       one <p>, so a reader looking up what `lag` means read six other
       columns first.

       Two fixes. A definition list gives each column its own row, so
       the column name is findable rather than buried mid-sentence. And
       each entry is cut to what the CELL means; the reasoning behind it
       — why the trigger is language-free, why a code repeats, why an
       empty cell is the right notation — is `design/matrix.md`, which
       is where someone asking "why is it like that" already goes. The
       page is a legend; the doc is the argument.

       The `kind` entry is GONE from here: it is the prepended glossary
       above the table. Leaving both was a duplication introduced the
       same day the glossary landed. *)
  in
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
        (List.map m.columns ~f:(fun c ->
             Printf.sprintf "<th class=\"%s\">%s</th>"
               (if is_group_start c then "gs" else "")
               (esc c)))
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
                          let base =
                            match s.title with
                            | Some t -> t ^ " · " ^ r.scenario
                            | None -> r.scenario
                          in
                          (* WHY it is red — the agreement that failed
                             while reading this artifact. Without the
                             name the colour would say "something about
                             this is wrong", which is the vagueness the
                             failing-action cell already had *)
                          match s.implicated with
                          | None -> base
                          | Some slugs -> base ^ " · implicated by " ^ slugs
                        in
                        let inner =
                          match s.url with
                          | Some url ->
                              Printf.sprintf "<a href=\"%s\">%s</a>" (esc url)
                                (esc s.text)
                          | None -> esc s.text
                        in
                        Printf.sprintf
                          "<td class=\"set%s\" title=\"%s\">%s</td>"
                          (match s.implicated with
                           | None -> ""
                           | Some _ -> " blamed")
                          (esc title) inner
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
                        (* a CHECK cell shows its coverage beside the
                           mark, and carries a class of its own so the
                           page can set it apart from the actions it
                           sits between *)
                        let is_check =
                          List.mem m.check_columns tag ~equal:String.equal
                        in
                        (* an ARTIFACT cell holds a summary, not a
                           verdict, so [cell_cls] would read its text
                           as an unknown mark; it gets its own class,
                           and turns red only when a check that read
                           it failed *)
                        let is_artifact =
                          List.mem m.artifact_columns tag ~equal:String.equal
                        in
                        let cls =
                          (if is_artifact then
                             if Option.is_some c.detail then "art blamed"
                             else "art"
                           else
                             cell_cls c.mark ^ if is_check then " chk" else "")
                          ^ if is_group_start tag then " gs" else ""
                        in
                        Printf.sprintf
                          "<td class=\"%s\" title=\"%s · %s · %s%s\"><span class=\"mk\">%s</span></td>"
                          cls (esc r.scenario) (esc tag) (esc c.provision)
                          (esc why)
                          (esc
                             (if is_check then c.mark ^ " " ^ c.provision
                              else c.mark))
                    (* a BLANK still carries the group rule: the border
                       is a line down the table separating one action's
                       columns from the next, and a line that skips the
                       empty cells is not a line, it is a scatter of
                       ticks (2026-09-14, user) *)
                    | _ ->
                        Printf.sprintf "<td class=\"blank%s\"></td>"
                          (if is_group_start tag then " gs" else "")))
           in
           Printf.sprintf
             "<tr><td class=\"idx\" title=\"%s\">%d</td><td class=\"proj\">%s</td>%s<td class=\"platform\">%s</td>%s</tr>"
             (esc r.code) r.index (esc r.project) setting_cells
             (esc r.platform) cells))
  in
  let page =
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
/* a CHECK column reads as an annotation on the action beside it, not
   as another step: lighter, smaller, and visually subordinate so the
   chain of actions still scans as the spine of the row */
td.chk { font-size: .72rem; opacity: .85; background: #fbfcfd; letter-spacing: -.02em; }
/* an artifact a failing CHECK was reading. The same red as a failed
   cell, because it is the same finding seen from the other end — the
   check says what disagreed, this says what it disagreed about. */
td.set.blamed { background: #ffebe9; box-shadow: inset 2px 0 0 #cf222e; }
/* an ARTIFACT cell: what the step left behind, as the inspector
   recorded it. Monospace because the contents line up column-wise
   (a soname tail, then a count), and quiet because it is context for
   the verdicts around it rather than a verdict itself. */
td.art { font-family: ui-monospace, monospace; font-size: .72rem; color: #57606a; background: #f6f8fa55; }
td.art.blamed { background: #ffebe9; color: #82071e; box-shadow: inset 2px 0 0 #cf222e; }
th.seth { background: #eef1f4; }
td.platform { color: #57606a; font-size: .75rem; }
td.idx { color: #57606a; font-size: .75rem; text-align: right; }
td .prov { color: #57606a; font-family: ui-monospace, monospace; font-size: .7rem; margin-right: 5px; }
td .mk { font-weight: 600; }
td.ok { background: #dafbe1; } td.xfail { background: #fff8c5; }
td.fail { background: #ffebe9; } td.fail .mk { font-weight: 800; }
td.notrun { color: #8c959f; } td.blocked { color: #57606a; background: #f6f8fa; }
td.blank { background: #f6f8fa; }
/* the CHECK KEY: the column heads are codes, so this is how the table
   is read at all — shown, not hidden behind a disclosure. */
div.key { margin: 0 0 .9rem; font-size: .8rem; }
div.keyh { font-weight: 600; margin-bottom: .3rem; }
table.keytbl { border-collapse: collapse; margin-top: .5rem; }
table.keytbl th, table.keytbl td { border: 1px solid #d0d7de; padding: .2rem .5rem; text-align: left; font-weight: 400; }
table.keytbl th { background: #f6f8fa; font-weight: 600; }
table.keytbl td.kc { font-family: ui-monospace, monospace; font-weight: 700; }
span.kq { color: #8c959f; }
/* THE AGREEMENT OVERVIEW's grid cells are two letters wide and the whole point
   is the SHAPE they make across a row, so colour carries the meaning and
   the text only confirms it: a reader should see where R sits relative
   to D before reading either. */
table.grid th.gcol { font-family: ui-monospace, monospace; font-size: .62rem;
  writing-mode: vertical-rl; transform: rotate(180deg); white-space: nowrap;
  padding: .3rem .15rem; vertical-align: bottom; }
table.grid td.g { text-align: center; font-family: ui-monospace, monospace;
  font-size: .65rem; font-weight: 700; padding: .2rem .25rem; }
/* WHERE THE CODE IS. `none` is red because an agreement with no
   evaluator is the table's real to-do list — the status word said
   "planned" without saying planned WHERE. */
table.grid td.impl { font-family: ui-monospace, monospace; font-size: .68rem;
  white-space: nowrap; }
table.grid td.impl.none { background: #ffebe9; color: #a40e26; font-weight: 700; }
/* AN EXISTING TOOL that answers the same claim, and RED like any other
   unimplemented cell (2026-09-21, user: "given the tool is not
   implemented yet, can we also show them in red").

   The column answers one question — does this check run here — and for
   a tool we name but never invoke the answer is no, exactly as it is
   for a claim nobody wrote an evaluator for. Two different reasons, one
   honest colour; the CELL still distinguishes them, because an
   unimplemented claim of ours reads `family·—` and a tool's row reads
   the tool's name. Italic keeps the second recognisable at a glance. */
tr.extrow { background: #fffafa; }
tr.extrow td.kc { color: #a40e26; }
table.grid td.impl.ext { background: #ffebe9; color: #a40e26;
  font-style: italic; }
table.grid td.lm { font-size: .72rem; white-space: nowrap; }
/* WHERE THE CLAIM COMES FROM. Its own class, not `lm`'s, because the
   overview pin counts `lm` cells against the lang/mech labels and a
   third cell sharing the class silently broke that count. */
table.grid td.kind { font-size: .72rem; white-space: nowrap; color: #57606a; }
/* THE TABLE'S OWN VERDICT — whether it passed its own laws. Quiet when
   it passes; a reader should notice it only when it has something to
   say, which is why the failing form is the one that gets colour. */
p.verdict { font-size: .78rem; color: #1a7f37; margin: .2rem 0 .6rem;
  font-family: ui-monospace, monospace; }
p.verdict.bad { color: #a40e26; font-weight: 700; }
/* the kind glossary, above the data that uses it */
div.kinds { font-size: .8rem; margin: 0 0 .8rem; max-width: 62rem; }
div.kinds dl { margin: .4rem 0 .4rem; display: grid;
  grid-template-columns: max-content 1fr; gap: .15rem .7rem; }
div.kinds dt { font-family: ui-monospace, monospace; font-weight: 700;
  color: #0a3069; }
div.kinds dd { margin: 0; }
/* THE COLUMN LEGEND, one row per column. It used to be a single
   paragraph that every new column appended to, so looking up `lag`
   meant reading six others first; a list makes the term findable.
   Entries say what the CELL means — the reasoning lives in
   design/matrix.md. (No angle brackets in this comment on purpose: a
   CSS comment is raw text to the parser, but a tag spelled here makes
   every tool that greps the page report a paragraph that is not one.) */
dl.legend { font-size: .78rem; margin: .5rem 0 .6rem; max-width: 62rem;
  display: grid; grid-template-columns: max-content 1fr; gap: .2rem .8rem; }
dl.legend dt { font-family: ui-monospace, monospace; font-weight: 700;
  color: #0a3069; white-space: nowrap; }
dl.legend dd { margin: 0; color: #57606a; }
td.g.rd { background: #d1e7dd; color: #0a3622; }   /* rule and check together */
td.g.rr { background: #ffe8cc; color: #7a3e00; }   /* the rule ran here */
td.g.dd { background: #dbeafe; color: #0a3069; }   /* the check fires here */
td.g.nn { background: #fbfcfd; }
td.g.tgt { background: #f0e6ff; color: #512a97; }   /* an artifact the claim ranges over */
h2 { font-size: 1rem; margin: 1.6rem 0 .5rem; padding-bottom: .25rem;
  border-bottom: 1px solid #d0d7de; font-weight: 600; }
/* the left edge of one action's group of columns — on EVERY cell in
   the column including the blanks, so it reads as a rule down the
   table rather than a scatter of ticks. Thin, because it separates
   rather than emphasises. */
th.gs, td.gs { border-left: 1px solid #afb8c1; }
</style></head><body>
<h1>canary — what is checked, and what it decided</h1>
<p class="meta">This page is a RECORD: what ran here, and what it decided.
For the general mechanism behind it — the chains that can exist, the
bridges that join two package ecosystems, and where a claim could sit —
see <a href="../overview.html">the overview</a>. It carries no
verdicts except two columns of its agreement table, which count what
the runs decided.</p>
<div class="meta">generated %s — rows = project × scenario (one enumerated world each). The SHADED leading columns are the world's SETTING: one per declared artifact, showing its placement (F = fetched, B = built, I = installed/staged, V = vendored; source cells link to the ref). The action columns then carry verdicts only — hover a cell for the scenario id, the artifact's stage, and the reason. The # column is the global row index (hover it for the stable row code — the historical pointer). A <b>_pre:</b> / <b>_post:</b> column is ONE AGREEMENT at one point in the chain — <i>_pre</i> a requirement the next action depends on, <i>_post</i> a verdict on what the last one made — and its cell is that agreement's own outcome, so a column can be read down the rows and compared. A claim gets a column only where it can be decided: not where it is unimplemented, and not where the mechanism cannot carry it (an OCaml <i>.a</i> archive records no NEEDED, so the identity claims have no column on that side and do on Python's shared object). An <b>=artifact</b> column is not a stage and nothing runs there — it is what the action LEFT BEHIND, read off the inspection that step wrote (a library shows its soname tail and export count, a binding its module count). It turns red when a check that read it failed, so a finding names both the claim that broke and the artifact it was about.</div>
<p class="meta"><b>The agreement overview has moved</b> to
<a href="../overview.html#overview">the overview page</a>. It is the
TEMPLATE of the table below — that one says what a run decided, this one
says what the shape of the checking IS — so an empty column here can be
looked up there, to see whether anything was ever meant to fill it. The
link is the cost of the split; the reason is that the template describes
mechanism and this page describes one machine's record.</p>

<h2>The result matrix — one row per enumerated world</h2>
<div class="wrap"><table><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>
</body></html>|}
      (esc generated_at) header body
  in
  (recovery_grid, page)

(** THE OVERVIEW'S OWN STYLING, so the table can be rendered somewhere
    other than this page (2026-09-23).

    Found the hard way: moving the block produced a table using 21
    classes the receiving page did not define, so every R/D mark, every
    red unimplemented cell and the verdict line rendered as plain text.
    A table whose whole point is the SHAPE the marks make across a row
    is not readable without them.

    Written against the receiving page's colour tokens rather than this
    page's literals, so it follows dark mode where the host supports it
    and degrades to the same greys where it does not.

    ⚠ TO CLEAN UP: this page's own style block still carries the
    originals, now dead here since the overview left. They are unused
    rather than wrong, and deleting thirty scattered rules from one
    literal is its own edit. *)
let overview_css =
  {|table.grid{border-collapse:collapse;font-size:.8rem;width:100%}
table.grid th,table.grid td{border:1px solid var(--line);padding:.22rem .4rem}
table.grid th.gcol{font-family:ui-monospace,monospace;font-size:.62rem;
writing-mode:vertical-rl;transform:rotate(180deg);white-space:nowrap;
padding:.3rem .15rem;vertical-align:bottom}
table.grid td.g{text-align:center;font-family:ui-monospace,monospace;
font-size:.65rem;font-weight:700;padding:.2rem .25rem}
table.grid td.impl{font-family:ui-monospace,monospace;font-size:.68rem;
white-space:nowrap}
table.grid td.impl.none,table.grid td.impl.ext{
background:color-mix(in srgb,var(--warn) 16%,transparent);
color:var(--warn);font-weight:700}
table.grid td.impl.ext{font-style:italic;font-weight:400}
tr.extrow{background:color-mix(in srgb,var(--warn) 6%,transparent)}
tr.extrow td.kc{color:var(--warn)}
table.grid td.lm{font-size:.72rem;white-space:nowrap}
table.grid td.kind{font-size:.72rem;white-space:nowrap;color:var(--mut)}
th.seth{background:var(--card)}
td .mk{font-weight:600}
table.keytbl{border-collapse:collapse;margin-top:.5rem;font-size:.82rem}
table.keytbl th,table.keytbl td{border:1px solid var(--line);
padding:.2rem .5rem;text-align:left;font-weight:400}
table.keytbl th{background:var(--card);font-weight:600}
table.keytbl td.kc{font-family:ui-monospace,monospace;font-weight:700}
span.kq{color:var(--mut)}
p.verdict{font-size:.78rem;color:#1a7f37;margin:.2rem 0 .6rem;
font-family:ui-monospace,monospace}
p.verdict.bad{color:var(--warn);font-weight:700}
div.kinds{font-size:.8rem;margin:0 0 .8rem;max-width:62rem}
div.kinds dl,dl.legend{margin:.4rem 0;display:grid;
grid-template-columns:max-content 1fr;gap:.18rem .8rem}
div.kinds dt,dl.legend dt{font-family:ui-monospace,monospace;
font-weight:700;color:var(--acc);white-space:nowrap}
div.kinds dd,dl.legend dd{margin:0}
dl.legend{font-size:.78rem;max-width:62rem}
dl.legend dd{color:var(--mut)}
td.g.rd{background:#d1e7dd;color:#0a3622}
td.g.rr{background:#ffe8cc;color:#7a3e00}
td.g.dd{background:#dbeafe;color:#0a3069}
td.g.nn{background:transparent}
td.g.tgt{background:#f0e6ff;color:#512a97}
.grid-wrap{overflow-x:auto;border:1px solid var(--line);border-radius:8px}|}

(** The result page alone — what [write_web] needs. *)
let render_html (m : t) ~(generated_at : string) : string =
  snd (render_parts m ~generated_at)

(** The agreement overview alone — what the methodology page needs. *)
let agreement_overview (m : t) ~(generated_at : string) : string =
  fst (render_parts m ~generated_at)

(* The web file locations (the docs copy is the GH Pages view).

   ONE FILE PER PLATFORM (2026-08-26, user). [docs/] is TRACKED, so a
   single [matrix.html] makes two machines fight over one committed file:
   the mac's verdicts would overwrite the WSL box's and each run would
   read as a wholesale change. The eventual answer is a runner per
   platform feeding ONE aggregating viewer — a real design question about
   how a verdict names the world it was earned in (the same question the
   step fingerprint answers for the switch). This suffix POSTPONES it
   without letting the two machines corrupt each other's record: Linux
   keeps [matrix.html] (no churn, every existing link intact), macOS
   writes [matrix_mac.html] beside it. The suffix itself is
   [Canary_basic.platform_suffix] — shared with the per-project docs copy
   in [Canary_diagram], because both name the same tracked tree. *)
let matrix_filename () : string =
  "matrix" ^ Canary_basic.platform_suffix () ^ ".html"
let web_path ~projects_root = projects_root ^ "/" ^ matrix_filename ()
let docs_path () = "docs/canary/projects/" ^ matrix_filename ()

(** A HYPOTHETICAL RENDER MUST NOT BECOME THE RECORD (2026-08-26, caught
    by doing it). [--platform] lets one machine render the other's view;
    the tracked filename is chosen by [platform_suffix], which reads the
    SELECTED platform — so `--platform=wsl` on the mac wrote
    [matrix.html], the WSL box's committed record, with a matrix the mac
    had produced. That is precisely the cross-machine corruption the
    per-platform filename exists to prevent, arriving through the door
    the override opened.

    The fix is not a better filename, because there is no honest one: a
    mac's rendering of the WSL view is neither machine's record. So an
    overridden run writes the LOCAL copy only (look at it, diff it, dump
    it) and leaves [docs/] alone, saying so. What lands in the tracked
    tree stays exactly "what this machine measured about itself". *)
let write_web ~projects_root (m : t) ~(generated_at : string) : unit =
  let html = render_html m ~generated_at in
  let hypothetical = Canary_store.platform_is_overridden () in
  let targets =
    if hypothetical then [ web_path ~projects_root ]
    else [ web_path ~projects_root; docs_path () ]
  in
  List.iter targets ~f:(fun path ->
      let oc = Stdlib.open_out path in
      Stdlib.output_string oc html;
      Stdlib.close_out oc);
  if hypothetical then
    Fmt.pr
      "Wrote %s (%d rows) — docs/ NOT updated: --platform render of %s is \
       not this machine's record@."
      (web_path ~projects_root) (List.length m.rows)
      (Canary_store.string_of_platform (Canary_store.platform ()))
  else
    Fmt.pr "Wrote %s and %s (%d rows)@." (web_path ~projects_root)
      (docs_path ()) (List.length m.rows)

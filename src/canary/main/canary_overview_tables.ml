(** §2's agreements by layer, §2.2's census of claim sites, and §3's
    tables of what canary covers — the package managers, the binding
    mechanisms, the cooperations and the chains canary runs. Every cell is
    computed from canary's code: the claim sites and the registry, the
    drivers and {!Canary_pm_solo}, the mechanism catalogue, the bridge
    model, {!Canary_topology}'s cooperations and the projects'
    declarations; the prose columns are written in those modules. *)

open Base
module T = Canary_topology
module E = Canary_overview_exhibits

let esc = Canary_overview_assets.esc

(** A table that may be wider than the page scrolls on its own. *)
let wide (html : string) = {|<div class="widetable">|} ^ html ^ "</div>"

(* ── §2: the agreements by layer ── *)

(** A placed claim's parts in each layer, in [T.all_components] order:
    each part as its node and what is read there. *)
let layer_cells (cs : T.claim_site) : string list list =
  List.map T.all_components ~f:(fun c ->
      List.filter_map cs.T.cs_parts ~f:(fun pt ->
          if Poly.equal pt.T.pt_component c then
            let node =
              Option.value_map (T.node_by_id pt.T.pt_node) ~default:pt.T.pt_node ~f:(fun n ->
                  n.T.nd_label)
            in
            Some (node ^ ": " ^ pt.T.pt_reads)
          else None))

let format_name = function Canary_store.Elf -> "ELF" | Canary_store.Macho -> "Mach-O"

(** Whether a claim applies on an object format, and how far canary is:
    [checked] (an evaluator), [planned] (a registry row with none), [n/a]
    (the row excludes the format), [candidate] (not a registry row, so it
    states no format). *)
let format_word (cs : T.claim_site) (f : Canary_store.object_format) : string =
  match Canary_agreement.agreement_named cs.T.cs_claim with
  | None -> "candidate"
  | Some r ->
      if not (List.mem r.Canary_agreement.ag_formats f ~equal:Canary_store.equal_object_format)
      then "n/a"
      else if T.implemented cs then "checked"
      else "planned"

(** §2's first table: one row per placed claim, a column per layer with
    the parts it relates there, and a column per object format. *)
let layers_table () =
  let row (cs : T.claim_site) =
    let cell parts =
      Printf.sprintf "<td>%s</td>" (String.concat ~sep:"<br>" (List.map parts ~f:esc))
    in
    let word f =
      let w = format_word cs f in
      Printf.sprintf "<td class=\"fmt %s\">%s</td>"
        (String.map w ~f:(fun c -> if Char.equal c '/' then '-' else c))
        (esc w)
    in
    Printf.sprintf "<tr><td><code>%s</code></td><td><code>%s</code></td>%s%s</tr>"
      (esc (Canary_agreement_common.short_code_of_slug cs.T.cs_claim))
      (esc cs.T.cs_claim)
      (String.concat (List.map (layer_cells cs) ~f:cell))
      (String.concat (List.map Canary_agreement.all_formats ~f:word))
  in
  wide
    (E.table ~cls:"keytbl layers" "tab-layers"
    ^ "<thead><tr><th>code</th><th>agreement</th>"
    ^ String.concat
        (List.map T.all_components ~f:(fun c ->
             Printf.sprintf "<th>%s</th>" (esc (T.string_of_component c))))
    ^ String.concat
        (List.map Canary_agreement.all_formats ~f:(fun f ->
             Printf.sprintf "<th>%s</th>" (esc (format_name f))))
    ^ "</tr></thead><tbody>"
    ^ String.concat (List.map T.claim_sites ~f:row)
    ^ "</tbody></table>")

(** The same table, for the terminal: per claim, the formats on its line
    and a line per layer it reads. *)
let pp_layers () : string =
  let claim (cs : T.claim_site) =
    Printf.sprintf "  %-6s %s  [%s]" (Canary_agreement_common.short_code_of_slug cs.T.cs_claim)
      cs.T.cs_claim
      (String.concat ~sep:", "
         (List.map Canary_agreement.all_formats ~f:(fun f ->
              format_name f ^ " " ^ format_word cs f)))
    :: List.concat
         (List.map2_exn T.all_components (layer_cells cs) ~f:(fun c parts ->
              List.map parts ~f:(fun p ->
                  Printf.sprintf "         %-9s %s" (T.string_of_component c) p)))
  in
  String.concat ~sep:"\n"
    ("the agreements by layer — the part of the chain each reads in each layer, and the \
      object formats it applies to"
    :: List.concat_map T.claim_sites ~f:claim)

(** §2.2: every edge with the claims placed on it, checked and named. *)
let claim_sites_table () =
  let row (e : T.edge) =
    let ps = T.claim_sites_on e.T.eg_id in
    let impl = List.count ps ~f:T.implemented in
    let cand = List.length ps - impl in
    let names =
      if List.is_empty ps then
        "<em>nothing — this relation is recovered by no claim</em>"
      else
        String.concat ~sep:", "
          (List.map ps ~f:(fun p ->
               Printf.sprintf "<code>%s</code>%s" (esc p.T.cs_claim)
                 (if T.implemented p then "" else "<sup>?</sup>")))
    in
    let annotation =
      match e.T.eg_annotation with
      | T.Action f ->
          Printf.sprintf "<code>%s</code>"
            (esc (Canary_action_family.to_string f))
      | T.Agreement slug -> Printf.sprintf "claim <code>%s</code>" (esc slug)
      | T.Info s -> Printf.sprintf "<em>%s</em> — we run nothing" (esc s)
    in
    Printf.sprintf
      "<tr%s><td><code>%s</code></td><td class=\"n\">%s</td><td>%s</td><td \
       class=\"n\">%d / %d</td><td>%s</td></tr>"
      (if List.is_empty ps then " class=\"bare\"" else "")
      (esc e.T.eg_id) annotation (esc e.T.eg_tool) impl cand names
  in
  Printf.sprintf
    "%s<thead><tr><th>edge</th><th>annotation</th><th>whose rule \
     runs</th><th>impl / cand</th><th>claims (<sup>?</sup> = no evaluator)</th></tr></thead><tbody>%s</tbody></table>"
    (E.table "tab-census")
    (String.concat (List.map T.edges ~f:row))

(* ── §3 ── *)

(** One of §3's tables, captioned: its head, then its rows. *)
let cov_table (id : string) (head : string) (rows : string) : string =
  wide (E.table ~cls:"cov" id ^ head ^ "<tbody>" ^ rows ^ "</tbody></table>")

let cells (xs : string list) =
  "<tr>" ^ String.concat (List.map xs ~f:(fun x -> "<td>" ^ x ^ "</td>")) ^ "</tr>"

let heads (xs : string list) =
  "<thead><tr>"
  ^ String.concat (List.map xs ~f:(fun x -> "<th>" ^ x ^ "</th>"))
  ^ "</tr></thead>"

(** Which projects fetch through [pm], read from the providers their
    artifact tables name. A system package names both platforms' packages,
    so it counts for apt and for brew. *)
let pm_users (projects : (string * Canary_project_run.project_run) list)
    (pm : Canary_store.package_manager) : string list =
  List.filter_map projects ~f:(fun (name, pr) ->
      let uses =
        List.exists pr.Canary_project_run.pr_artifacts ~f:(fun row ->
            match Canary_project_spec.provider_of_row row with
            | Some (Canary_store_config.Sys_pkg _) ->
                List.mem [ Canary_store.Apt; Canary_store.Brew ] pm ~equal:Poly.equal
            | Some (Canary_store_config.Lang_pkg { pm = p; _ }) -> Poly.equal p pm
            | _ -> false)
      in
      if uses then Some name else None)

(** §3.1: each package manager on its own. *)
let pm_solo_table projects =
  let row (r : Canary_pm_solo.row) =
    let pm = r.Canary_pm_solo.ps_pm in
    let unseen =
      Canary_pm_action.inside_install pm ~of_binding:true
      |> List.map ~f:(fun p ->
             Printf.sprintf "%s <span class=\"from\">%s</span>"
               (esc p.Canary_pm_action.ph_key)
               (match p.Canary_pm_action.ph_unseen with
                | Canary_pm_action.Not_yet _ -> "not yet"
                | Canary_pm_action.Out_of_reach _ -> "out of reach"))
    in
    let dash = function [] -> "—" | xs -> String.concat ~sep:"<br>" xs in
    cells
      [ Printf.sprintf "<b>%s</b><br><span class=\"from\">%s</span>"
          (esc (Canary_store.string_of_pm pm))
          (esc (Canary_pm_solo.scope_of pm));
        esc (Canary_pm_solo.store_of pm);
        esc r.Canary_pm_solo.ps_package;
        esc r.Canary_pm_solo.ps_versions;
        esc r.Canary_pm_solo.ps_ships;
        (* the terms §1 writes under "capability file" and "bridge package" *)
        Printf.sprintf "<b>%s</b>" (esc r.Canary_pm_solo.ps_capability);
        dash (List.map (Canary_bridge.kinds_of_pm pm) ~f:esc);
        dash unseen;
        (match pm_users projects pm with [] -> "—" | us -> esc (String.concat ~sep:", " us)) ]
  in
  cov_table "tab-pm"
    (heads
       [ "package manager"; "store"; "what a package is"; "its versions";
         "what it ships for others to read"; "its capability file";
         "bridges it defines"; "inside an install, unseen"; "used by" ])
    (String.concat (List.map Canary_pm_solo.table ~f:row))

(** Which projects bind through [m], per pass 2 — the mechanism each
    declared binding language resolves to. *)
let mechanism_users (projects : (string * Canary_project_run.project_run) list)
    (m : Canary_mechanism.mechanism) : string list =
  List.filter_map projects ~f:(fun (name, pr) ->
      let an = Canary_pipeline.analysed_of pr in
      if
        List.exists (T.binding_langs pr) ~f:(fun lang ->
            Poly.equal (Canary_project_analysis.mechanism_for an lang) m)
      then Some name
      else None)

(** The registered claims a binding through this mechanism can carry,
    whatever the project: pass 2's applicability, which reads the
    mechanism and the language and never the declaration. *)
let carried_by (i : Canary_mechanism.mechanism_info) : string list =
  Canary_project_analysis.carried_slugs ~mechanism:i.Canary_mechanism.mi_mechanism
    ~lang:i.Canary_mechanism.mi_lang ~declared:None

let claims_cell (i : Canary_mechanism.mechanism_info) : string =
  match carried_by i with
  | [] -> "—"
  | slugs ->
      String.concat ~sep:" "
        (List.map slugs ~f:(fun s ->
             Printf.sprintf {|<code title="%s">%s</code>|} (esc s)
               (esc (Canary_agreement_common.short_code_of_slug s))))

(** §3.2: the binding mechanisms, grouped by language as §1's buttons are. *)
let binding_table projects =
  let yes b = if b then "yes" else "no" in
  let row (i : Canary_mechanism.mechanism_info) =
    let m = i.Canary_mechanism.mi_mechanism in
    cells
      [ Printf.sprintf "<b>%s</b>" (esc (Canary_mechanism.string_of_mechanism m));
        esc (Canary_lang.string_of_lang i.Canary_mechanism.mi_lang);
        esc
          (match i.Canary_mechanism.mi_discipline with
           | Canary_mechanism.Static_c_abi -> "static C ABI"
           | Canary_mechanism.Dynamic_ffi -> "dynamic FFI");
        esc i.Canary_mechanism.mi_lib_coupling;
        yes i.Canary_mechanism.mi_compiles_a_stub;
        yes i.Canary_mechanism.mi_consumer_records_needed;
        yes i.Canary_mechanism.mi_exposes_typed_stub;
        claims_cell i;
        (match mechanism_users projects m with
         | [] -> "— <span class=\"from\">not wired</span>"
         | us -> esc (String.concat ~sep:", " us)) ]
  in
  cov_table "tab-mechanisms"
    (heads
       [ "mechanism"; "language"; "discipline"; "how the library is bound";
         "a compiled stub?"; "does the consumer record its NEEDED?";
         "a typed boundary?"; "claims checked for it"; "used by" ])
    (String.concat
       (List.map ~f:row
          (Canary_overview_join.by_language
             (fun (i : Canary_mechanism.mechanism_info) -> i.Canary_mechanism.mi_lang)
             Canary_mechanism.mechanism_catalogue)))

(** The instances of each cooperation, per world: a world that builds its
    binding does not go through the package gate its project declares. *)
let coop_groups projects =
  let insts = List.concat_map projects ~f:T.topologies_of_worlds in
  List.filter_map T.coop_catalogue ~f:(fun info ->
      match
        List.filter insts ~f:(fun ((t : T.t), _) ->
            Poly.equal (T.coop_of t) info.T.co_kind)
      with
      | [] -> None
      | xs -> Some (info, xs))

(** §3.3: how two package managers cooperate, and the kinds no project
    instantiates yet. *)
let coop_table projects =
  let groups = coop_groups projects in
  let row ((info : T.coop_info), (xs : (T.t * T.instance) list)) =
    let pairs =
      List.map xs ~f:(fun ((t : T.t), _) ->
          T.string_of_supplier t.T.tp_lang ^ " ↔ " ^ T.string_of_supplier t.T.tp_sys)
      |> List.dedup_and_sort ~compare:String.compare
    in
    let who =
      List.map xs ~f:(fun ((t : T.t), (i : T.instance)) ->
          let bridge =
            match T.bridges_of_join t.T.tp_join with
            | [] -> ""
            | bs -> " (" ^ String.concat ~sep:" + " (List.map bs ~f:T.string_of_gated) ^ ")"
          in
          (* a binding not taken from a package manager says so: no gate
             applies to it *)
          let side =
            match t.T.tp_lang with
            | T.By_pm _ -> ""
            | s -> " (binding " ^ T.string_of_supplier s ^ ")"
          in
          i.T.in_project ^ bridge ^ side)
      |> List.dedup_and_sort ~compare:String.compare
    in
    (* the kinds of bridge its chains join through: §1's term for the
       bridge package in this cooperation *)
    let bridge_kinds =
      List.concat_map xs ~f:(fun ((t : T.t), _) ->
          List.map (T.bridges_of_join t.T.tp_join) ~f:(fun g ->
              Canary_bridge.kind_term g.T.gb_bridge))
      |> List.dedup_and_sort ~compare:String.compare
    in
    cells
      [ Printf.sprintf "<b>%s</b><br><span class=\"from\">draft: %s</span>"
          (esc info.T.co_name) (esc info.T.co_draft);
        esc (String.concat ~sep:", " pairs);
        (match bridge_kinds with
         | [] -> "—"
         | ks -> Printf.sprintf "<b>%s</b>" (esc (String.concat ~sep:" · " ks)));
        esc info.T.co_package_join;
        esc info.T.co_artifact_join;
        esc info.T.co_versions;
        esc info.T.co_recorded;
        esc (String.concat ~sep:", " who) ]
  in
  let covered = List.map groups ~f:(fun (i, _) -> i.T.co_kind) in
  let uncovered =
    List.filter T.coop_catalogue ~f:(fun i ->
        not (List.mem covered i.T.co_kind ~equal:Poly.equal))
  in
  cov_table "tab-cooperation"
    (heads
       [ "cooperation"; "the two sides"; "its bridge"; "how the packages are joined";
         "what meets the artifacts"; "how a version constraint travels";
         "what canary records"; "instances" ])
    (String.concat (List.map groups ~f:row))
  ^ Printf.sprintf
      "<p class=\"mechnote\">Classified but instantiated by no project yet: %s.</p>"
      (esc
         (String.concat ~sep:"; "
            (List.map uncovered ~f:(fun i -> i.T.co_name))))

(** §3.4: the chains canary runs — one per project, binding language and
    pair of sides — the same list §1's package buttons are
    ([Canary_overview_join.cases_of]); each row links to its chain drawn
    there. *)
let chains_table (j : Canary_overview_join.t) =
  let module J = Canary_overview_join in
  cov_table "tab-chains"
    (heads
       [ "project"; "language"; "binding (§3.2)"; "language side (§3.1)";
         "native side (§3.1)"; "cooperation (§3.3)" ])
    (String.concat
       (List.map j.J.jn_cases ~f:(fun c ->
            cells
              [ Printf.sprintf {|<a href="#chain=%s">%s</a>|} (esc c.J.cs_id)
                  (esc c.J.cs_project);
                esc (Canary_lang.string_of_lang c.J.cs_lang);
                esc (Canary_mechanism.string_of_mechanism c.J.cs_mechanism);
                esc (T.string_of_supplier c.J.cs_topology.T.tp_lang);
                esc (T.string_of_supplier c.J.cs_topology.T.tp_sys);
                esc (T.character c.J.cs_topology) ])))

(** §3.3's two notes: the bindings in a wrong row for a known reason, and
    why no chain is capability-mediated. Both computed. *)
let topology_notes (projects : (string * Canary_project_run.project_run) list) =
  let unreachable =
    T.unreachable_gates (T.topologies projects)
    |> List.map ~f:(fun i ->
           Printf.sprintf "%s/%s" i.T.in_project
             (Canary_lang.string_of_lang i.T.in_lang))
    |> List.dedup_and_sort ~compare:String.compare
  in
  let gates =
    if List.is_empty unreachable then ""
    else
      Printf.sprintf
        "<div class=\"note warn\"><strong>%d bindings sit in a wrong row, \
         for a known reason</strong> (%s). Each declares a conf package, \
         but on the opam-binding template's own record: the template leaves \
         <code>pr_binding_decls</code> empty, so the gate never reaches this \
         derivation and the row reads <code>⚠ UNDECLARED</code>. That is \
         <code>project/issues.md</code> §2 — a mechanism declared in two \
         places, one of them read — at its second consumer.</div>"
        (List.length unreachable)
        (esc (String.concat ~sep:", " unreachable))
  in
  let cap =
    if T.no_capability_file_declared projects then
      "<div class=\"note warn\"><strong>No row is capability-mediated, \
       because no project declares a capability file.</strong> The \
       projects declare <code>Headers</code>, <code>Runtime_lib</code> and \
       <code>Link_lib</code> as their C API's components and none declares \
       a <code>Pc_file</code>. That is an absence of DECLARATION, not of \
       the file: pkg-config is demonstrably in use — the conf packages' \
       checks read it, and canary's own library locator does. A capability \
       file is not a bridge; where a row says <em>artifact validation</em>, \
       that is the bridge's own check.</div>"
    else ""
  in
  gates ^ cap

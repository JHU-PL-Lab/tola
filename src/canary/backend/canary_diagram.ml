open Base
open Canary_basic
open Canary

(* ── Diagram rendering ──
   Step-level Mermaid renderers and the write_project_output orchestrator.
   The schema renderer (mermaid_of_action_rule_schema) lives in canary.ml.

   Full (step-level)        → mermaid_full
   View dispatch            → mermaid_view
   Fallback filter renderer → mermaid_of_steps

   check_diagram_invariant verifies coverage + connectivity per diagram.

   write_project_output orchestrates all diagrams + HTML + index per run. *)


let label_of_artifact_kind k =
  String.tr ~target:'_' ~replacement:' ' (string_of_artifact_kind k)

let node_id_of_kind k =
  [%string "%{string_of_artifact_kind k}_node"]

let inspect_label_of_tag tag =
  let stub = String.is_suffix tag ~suffix:"_stub_inspect" in
  let base =
    if stub then String.chop_suffix_exn tag ~suffix:"_stub_inspect"
    else String.chop_suffix_exn tag ~suffix:"_inspect"
  in
  let subject =
    List.find_map
      [ "pack_binding_"; "probe_binding_"; "fetch_binding_"; "build_binding_"
      ; "pack_"; "probe_"; "fetch_"; "build_"; "install_"; "scan_" ]
      ~f:(fun pfx -> String.chop_prefix base ~prefix:pfx)
    |> Option.value ~default:base
  in
  if stub then [%string "inspect_%{subject}_stub"]
  else [%string "inspect_%{subject}"]

(* summary_rules : list of (parent rule, tag_suffix) pairs.

   - One pair per summary follow-up step that appears in the run.
   - Same rule can appear with multiple suffixes (e.g.
     Fetch (Binding OCaml) has both "_inspect" — mli — and
     "_stub_inspect" — c_stub).
   - The diagram emits one summary node per pair.

   step_ids : optional table from step tag to its step index (1-based,
   execution order). When supplied, action labels show all step indices
   that map to a given rule kind, like "probe_lib [3][4][5]" — useful
   when multiple step variants (apt / staged / build_tree) collapse into
   one schema-level node. Empty table → labels use a fresh sequential
   counter (legacy behaviour). *)
let mermaid_of_action_rule_schema ?status ?(has_scan = false) ?(chain_scan = false)
    ?(summary_rules : (rule * string) list = [])
    ?(step_ids : (string, int) Hashtbl.t option)
    ?(steps_by_rule_tag : (string, string list) Hashtbl.t option)
    ?(summary_tags_by_canonical : (string, string list) Hashtbl.t option)
    ?(expand_artifact : (artifact_kind * (string * string) list) option)
    ?(expand_probe_kinds : (artifact_kind * (string * string * string) list) list = [])
    ?(view_title : string option)
    ?(focal_predicate : (string -> bool) option)
    (rules : rule list) =
  let get_status tag = match status with
    | None -> None
    | Some tbl -> Hashtbl.find tbl tag
  in
  let buf = Buffer.create 1024 in
  let add s = Buffer.add_string buf s; Buffer.add_char buf '\n' in
  let has_configure = List.exists rules ~f:(fun r ->
      match r with Configure -> true | _ -> false)
  in
  let fetch_kinds =
    List.filter_map rules ~f:(fun r -> match r with Fetch k -> Some k | _ -> None)
  in
  let build_rules =
    List.filter rules ~f:(fun r ->
        match r with
        | Build_headers | Build_lib | Build_binding _ | Build_app -> true
        | _ -> false)
  in
  let install_rules =
    List.filter rules ~f:(fun r ->
        match r with
        | Install_lib -> true
        | _ -> false)
  in
  let publish_kinds =
    List.filter_map rules ~f:(fun r ->
        match r with Publish k -> Some k | _ -> None)
  in
  let probe_kinds =
    List.filter_map rules ~f:(fun r ->
        match r with Probe k -> Some k | _ -> None)
  in
  (* Artifact pool kinds: derived from rules — includes Binding lang variants *)
  let artifact_pool_kinds =
    List.filter_map rules ~f:(fun r ->
        match r with
        | Build_headers | Fetch Headers -> Some Headers
        | Build_lib | Fetch Lib -> Some Lib
        | Build_binding lang | Fetch (Binding lang) -> Some (Binding lang)
        | Build_app | Fetch App -> Some App
        | _ -> None)
    |> List.dedup_and_sort ~compare:Poly.compare
  in
  let all_pool_kinds = Source :: artifact_pool_kinds in
  let scan_nid = "A_scan_source" in
  (* Parent node id for a summary follow-up's incoming edge.
     Probe and Publish have their own action nodes; Fetch has no
     separate action node — the fetch ID is embedded in the artifact
     label — so the edge originates from the artifact pool node.
     Defined after kind_nid below as parent_action_nid_ex (expanded-aware). *)
  (* Summary nodes are uniquely identified by (parent rule, tag suffix).
     suffix is e.g. "_inspect" or "_stub_inspect". *)
  let summary_nid rule suffix =
    [%string "A_%{string_of_rule rule}%{suffix}"]
  in
  let summary_label rule suffix =
    (* e.g. fetch_binding_ocaml_stub_inspect *)
    string_of_rule rule ^ suffix
  in
  let source_upstream =
    if chain_scan && has_scan then scan_nid else node_id_of_kind Source
  in
  (* Action labels: when [step_ids] + [steps_by_rule_tag] are supplied,
     each schema-level node lists ALL step indices that map to it
     (e.g. probe_lib [3][4][5] when there are apt/staged/build_tree
     variants). Slots without any matching step (not-in-spec) get just
     the name; standalone callers (no step info) fall back to a fresh
     sequential counter so they still get [N] labels. *)
  let have_step_info =
    Option.is_some step_ids && Option.is_some steps_by_rule_tag
  in
  let action_counter = ref 0 in
  let next_id () = Int.incr action_counter; !action_counter in
  let label_with_ids name rule_tag =
    let ids =
      match steps_by_rule_tag, step_ids with
      | Some by_tag, Some id_tbl ->
          (match Hashtbl.find by_tag rule_tag with
           | Some tags ->
               List.filter_map tags ~f:(Hashtbl.find id_tbl)
               |> List.sort ~compare:Int.compare
           | None -> [])
      | _ -> []
    in
    if List.is_empty ids then
      if have_step_info then name (* not-in-spec slot — no bracket *)
      else
        let n = next_id () in
        [%string "%{name} [%{Int.to_string n}]"]
    else
      let id_str =
        List.map ids ~f:(fun i -> [%string "[%{Int.to_string i}]"])
        |> String.concat ~sep:""
      in
      [%string "%{name} %{id_str}"]
  in
  let action_label name = label_with_ids name name in
  (* Direct tag lookup — for follow-up steps (scan_source, *_inspect)
     that have a 1:1 step mapping but were excluded from the rule-tag
     bucket so they don't pollute parent labels. *)
  let direct_tag_label tag =
    let disp =
      if String.is_suffix tag ~suffix:"_inspect"
      then inspect_label_of_tag tag else tag
    in
    match step_ids with
    | Some tbl ->
        (match Hashtbl.find tbl tag with
         | Some n -> [%string "%{disp} [%{Int.to_string n}]"]
         | None -> if have_step_info then disp else action_label disp)
    | None -> action_label disp
  in
  (* Helpers for expand_artifact support.
     When expand_artifact = Some (kind, [(vid, label),...]), the focused
     artifact kind is split into per-variant docs nodes instead of the
     single collapsed node used in the overview. *)
  let is_expanded kind =
    match expand_artifact with
    | Some (exp_kind, _) -> Poly.equal kind exp_kind
    | None -> false
  in
  let expand_vars () =
    match expand_artifact with Some (_, vs) -> vs | None -> []
  in
  let expand_variant_nid kind vid =
    [%string "%{string_of_artifact_kind kind}_%{vid}_node"]
  in
  (* Canonical node id for a kind: for the expanded kind, use the
     "canonical consumer" variant (staged > build_tree > first pm).
     For other kinds, fall back to the normal node id. *)
  let kind_nid kind =
    if is_expanded kind then begin
      let vs = expand_vars () in
      let vid =
        if List.exists vs ~f:(fun (v,_) -> String.equal v "staged") then "staged"
        else if List.exists vs ~f:(fun (v,_) -> String.equal v "build_tree") then "build_tree"
        else (match vs with (v,_) :: _ -> v | [] -> "default")
      in
      expand_variant_nid kind vid
    end else node_id_of_kind kind
  in
  (* The artifact variant node produced by a pack (Publish) step: the first
     PM-like variant (opam/pip/fetch) that is not the consumed build_tree/staged
     input. Returns None when the kind is not expanded or has no distinct produced
     variant (e.g. only one variant = build_tree). *)
  let pack_produced_nid kind =
    if is_expanded kind then
      let vs = expand_vars () in
      (* The variant consumed by build_tree → pack (i.e. the build_tree or staged
         variant that feeds into the pack action). Exclude it so we don't produce
         a self-loop when Python binding has only one PM variant. *)
      let consumed_vid =
        if List.exists vs ~f:(fun (v, _) -> String.equal v "staged") then "staged"
        else if List.exists vs ~f:(fun (v, _) -> String.equal v "build_tree") then "build_tree"
        else (match vs with (v, _) :: _ -> v | [] -> "default")
      in
      let pm_like = List.filter vs ~f:(fun (v, _) ->
          not (String.equal v "build_tree")
          && not (String.equal v "staged")
          && not (String.equal v "default")
          && not (String.equal v consumed_vid)) in
      match pm_like with
      | [(v, _)] -> Some (expand_variant_nid kind v)
      | _ -> None
    else None
  in
  (* Helpers for expand_probe_kinds support.
     When expand_probe_kinds = Some (kind, [(probe_tag, variant_id, label),...]),
     the focused probe kind is split into one pill node per variant instead of
     a single collapsed node. variant_id matches the artifact expand_artifact
     variant, enabling per-variant edge routing. *)
  let is_probe_expanded kind =
    List.exists expand_probe_kinds ~f:(fun (k, _) -> Poly.equal k kind)
  in
  (* A Publish summary is "inlined" into the pack action label when the binding
     probe for that kind is NOT expanded (i.e. we're in a non-binding-focused view).
     In that case no separate pill node or dashed edge is emitted for it. *)
  (* A summary is "inlined" (no pill node, IDs go into parent's label) when the
     artifact kind it belongs to is not expanded in this view.
     Covers Publish, Probe, and Fetch binding summaries.  Inlined summaries keep
     their status entry (for edge colouring) but lose the separate pill node. *)
  let is_inlined_inspect rule =
    match rule with
    | Publish kind | Probe kind | Fetch kind -> not (is_probe_expanded kind)
    | _ -> false
  in
  (* Raw int IDs from steps_by_rule_tag for a given canonical rule name. *)
  let action_int_ids name =
    match steps_by_rule_tag, step_ids with
    | None, _ | _, None -> []
    | Some tbl, Some sids ->
        let tags = Option.value (Hashtbl.find tbl name) ~default:[] in
        List.filter_map tags ~f:(fun t -> Hashtbl.find sids t)
  in
  (* Raw int IDs for all summary entries of a rule — used when inlining. *)
  let summary_int_ids rule =
    List.concat_map summary_rules ~f:(fun (srule, suffix) ->
        if not (Poly.equal srule rule) then []
        else
          let canonical = string_of_rule rule ^ suffix in
          match summary_tags_by_canonical, step_ids with
          | None, _ | _, None -> []
          | Some stbc, Some sids ->
              let tags = Option.value (Hashtbl.find stbc canonical) ~default:[] in
              List.filter_map tags ~f:(fun t -> Hashtbl.find sids t))
  in
  (* Build an action label with action + summary IDs merged and sorted together. *)
  let action_label_with_inspect name rule =
    let all_ids =
      (action_int_ids name @ summary_int_ids rule)
      |> List.sort ~compare:Int.compare
      |> List.map ~f:(fun n -> [%string "[%{Int.to_string n}]"])
      |> String.concat ~sep:""
    in
    name ^ (if String.is_empty all_ids then "" else " " ^ all_ids)
  in
  (* Formatted summary-only ID suffix — used for fetch artifact labels where the
     fetch action IDs are already embedded by label_with_ids. *)
  let inline_inspect_ids rule =
    summary_int_ids rule
    |> List.sort ~compare:Int.compare
    |> List.map ~f:(fun n -> [%string "[%{Int.to_string n}]"])
    |> String.concat ~sep:""
  in
  let probe_expand_items kind =
    match List.find expand_probe_kinds ~f:(fun (k, _) -> Poly.equal k kind) with
    | Some (_, items) -> items
    | None -> []
  in
  (* parent_action_nid for summary edges: Fetch → artifact node (expanded-aware);
     Probe → first expanded probe node when probe is expanded. *)
  let parent_action_nid_ex rule =
    match rule with
    | Fetch kind -> kind_nid kind
    | Probe kind when is_probe_expanded kind ->
        (match probe_expand_items kind with
         | (first_tag, _, _) :: _ -> [%string "A_%{first_tag}"]
         | [] -> [%string "A_%{string_of_rule rule}"])
    | _ -> [%string "A_%{string_of_rule rule}"]
  in
  (* For a summary (rule, suffix), return a list of (node_id, tag, parent_nid) triples.
     When the probe kind is expanded and per-variant summary tags exist in step_ids,
     emit one triple per probe variant so every concrete action has a diagram node.
     Falls back to one canonical triple otherwise. *)
  let summary_item_triples rule suffix =
    let canonical =
      (summary_nid rule suffix, summary_label rule suffix, parent_action_nid_ex rule)
    in
    match rule with
    | Probe kind when is_probe_expanded kind && String.equal suffix "_inspect" ->
        let variants = List.filter_map (probe_expand_items kind) ~f:(fun (probe_tag, _, _) ->
            let stag = probe_tag ^ "_inspect" in
            let known = match step_ids with
              | Some sids -> Hashtbl.mem sids stag
              | None -> false
            in
            if known then
              Some ([%string "A_%{probe_tag}_inspect"], stag, [%string "A_%{probe_tag}"])
            else None)
        in
        if List.is_empty variants then [ canonical ] else variants
    | _ -> [ canonical ]
  in
  (* Label for a canonical summary node in the overview (non-expanded) case.
     Looks up ALL concrete step tags that map to this canonical tag and shows
     all their IDs: e.g. "probe_lib_inspect [18][20][22]". Falls back to
     direct_tag_label when no table is provided. *)
  let summary_all_ids_label canonical_tag =
    let disp = inspect_label_of_tag canonical_tag in
    match summary_tags_by_canonical, step_ids with
    | None, _ | _, None -> direct_tag_label canonical_tag
    | Some stbc, Some sids ->
        let concretes =
          Option.value (Hashtbl.find stbc canonical_tag) ~default:[canonical_tag]
        in
        let ids =
          List.filter_map concretes ~f:(fun t -> Hashtbl.find sids t)
          |> List.sort ~compare:Int.compare
          |> List.map ~f:(fun n -> [%string "[%{Int.to_string n}]"])
          |> String.concat ~sep:""
        in
        disp ^ (if String.is_empty ids then "" else " " ^ ids)
  in
  Option.iter view_title ~f:(fun t -> add ("%% " ^ t));
  add "graph LR";
  (* Artifact nodes — fetch action ID embedded in label when a Fetch rule
     exists, so it cross-references the log without adding a separate
     node. Multiple Fetch step variants (e.g. fetch_lib + fetch_lib_apt)
     all map to the same artifact pool node, so we collect their step
     ids together. *)
  List.iter all_pool_kinds ~f:(fun kind ->
      if is_expanded kind then begin
        (* Emit per-variant doc nodes wrapped in subgraph(s), mirroring mermaid_full.
           When a pack step produces a distinct PM variant (opam/pip), split into
           an input subgraph (build_tree / fetch variants) and a product subgraph. *)
        let vs = expand_vars () in
        let kind_lbl = label_of_artifact_kind kind in
        let kind_str = string_of_artifact_kind kind in
        (* Identify the product variant (output of install/pack) based on which rules
           are present in the schema.  "staged" comes from Install_lib; "opam"/"pip"
           come from the relevant Publish rule.  Everything else is an input variant. *)
        let product_vid =
          match kind with
          | Lib ->
              if List.exists rules ~f:(fun r -> Poly.equal r Install_lib)
              then Some "staged" else None
          | Binding lang ->
              if List.mem publish_kinds kind ~equal:Poly.equal then
                Some (match lang with
                  | Canary_lang.OCaml -> "opam"
                  | Canary_lang.Python -> "pip"
                  | _ -> "packed")
              else None
          | _ -> None
        in
        let input_vs = List.filter vs ~f:(fun (v, _) ->
            not (Option.equal String.equal (Some v) product_vid)) in
        let product_vs = List.filter vs ~f:(fun (v, _) ->
            Option.equal String.equal (Some v) product_vid) in
        let emit_doc_nodes indent vs =
          List.iter vs ~f:(fun (vid, vlabel) ->
              let nid = expand_variant_nid kind vid in
              add [%string "%{indent}%{nid}@{ shape: doc, label: \"%{vlabel}\" }"])
        in
        (match product_vs with
         | [] ->
             add [%string "    subgraph %{kind_str}_sg [\"%{kind_lbl}\"]"];
             emit_doc_nodes "      " input_vs;
             add "    end"
         | _ ->
             add [%string "    subgraph %{kind_str}_input_sg [\"%{kind_lbl}\"]"];
             emit_doc_nodes "      " input_vs;
             add "    end";
             let product_suffix = match kind with
               | Lib -> "product"
               | _ -> (match product_vs with (v, _) :: _ -> v | [] -> "packed")
             in
             add [%string "    subgraph %{kind_str}_product_sg [\"%{kind_lbl} (%{product_suffix})\"]"];
             emit_doc_nodes "      " product_vs;
             add "    end")
      end
      else begin
        let nid = node_id_of_kind kind in
        let lbl = label_of_artifact_kind kind in
        let label =
          if List.mem fetch_kinds kind ~equal:Poly.equal then begin
            let rule_tag = string_of_rule (Fetch kind) in
            let base = label_with_ids lbl rule_tag in
            (* In non-expanded views, fetch summaries are inlined into the artifact
               label rather than shown as separate pills. *)
            if is_inlined_inspect (Fetch kind) then
              base ^ inline_inspect_ids (Fetch kind)
            else base
          end else lbl
        in
        add [%string "    %{nid}@{ shape: docs, label: \"%{label}\" }"]
      end);
  add "";
  (* Scan action — hexagon, same as other active-transformation actions *)
  if has_scan then
    add [%string "    %{scan_nid}{{\"%{direct_tag_label \"scan_source\"}\"}}"];
  (* Configure + build actions — hexagon shape (active transformation) *)
  if has_configure then
    add [%string "    A_configure{{\"%{action_label \"configure\"}\"}}"];
  List.iter build_rules ~f:(fun r ->
      let name = string_of_rule r in
      add [%string "    A_%{name}{{\"%{action_label name}\"}}"]);
  (* Install actions — hexagon shape *)
  List.iter install_rules ~f:(fun r ->
      let name = string_of_rule r in
      add [%string "    A_%{name}{{\"%{action_label name}\"}}"]);
  (* Publish actions — hexagon shape.
     In non-binding-focused views the summary pill nodes are suppressed and their
     IDs are appended directly to the pack action label instead. *)
  List.iter publish_kinds ~f:(fun kind ->
      let name = string_of_rule (Publish kind) in
      let lbl = if is_inlined_inspect (Publish kind)
                then action_label_with_inspect name (Publish kind)
                else action_label name in
      add [%string "    A_%{name}{{\"%{lbl}\"}}"]);
  (* Probe actions — pill shape.
     Expanded probes emit one node per step variant instead of one collapsed node.
     Non-expanded probes inline their summary IDs into the label, all IDs sorted. *)
  List.iter probe_kinds ~f:(fun kind ->
      if is_probe_expanded kind then
        List.iter (probe_expand_items kind) ~f:(fun (probe_tag, _vid, label) ->
            add [%string "    A_%{probe_tag}([\"%{label}\"])"])
      else begin
        let name = string_of_rule (Probe kind) in
        let lbl = action_label_with_inspect name (Probe kind) in
        add [%string "    A_%{name}([\"%{lbl}\"])"]
      end);
  (* Summary actions — pill shape, one per (rule, suffix) pair.
     Covers Probe Lib (_inspect), Fetch (Binding lang) (_inspect +
     _stub_inspect), Publish (Binding lang) (same as Fetch), etc.
     Each summary tag is a real step tag, so use direct lookup to
     surface its individual step id. *)
  List.iter summary_rules ~f:(fun (rule, suffix) ->
      if not (is_inlined_inspect rule) then begin
        let triples = summary_item_triples rule suffix in
        (* One triple = collapsed overview node → show all concrete IDs.
           Multiple triples = expanded focused nodes → each shows its own ID. *)
        let collapsed = match triples with [ _ ] -> true | _ -> false in
        List.iter triples ~f:(fun (nid, tag, _parent) ->
            let label =
              if collapsed then summary_all_ids_label tag else direct_tag_label tag
            in
            add [%string "    %{nid}([\"%{label}\"])"])
      end);

  add "";
  (* Edges *)
  let edge_idx = ref 0 in
  let edge_tags = ref [] in
  let add_edge ?tag edge_str =
    add [%string "    %{edge_str}"];
    (match tag with
     | Some t -> edge_tags := (!edge_idx, t) :: !edge_tags
     | None -> ());
    Int.incr edge_idx
  in
  (* Scan edge: source_node -.-> scan (annotation/follow-up).
     The downstream scan -> configure edge stays solid (real dep ordering). *)
  if has_scan then begin
    add_edge ~tag:"scan_source"
      [%string "%{node_id_of_kind Source} -.-> %{scan_nid}"]
  end;
  (* Configure edge: source_upstream → configure *)
  if has_configure then
    add_edge ~tag:"configure"
      [%string "%{source_upstream} --> A_configure"];
  (* Build edges *)
  List.iter build_rules ~f:(fun r ->
      let name = string_of_rule r in
      let action_id = [%string "A_%{name}"] in
      match r with
      | Build_headers ->
          if has_configure then
            add_edge ~tag:name [%string "A_configure --> %{action_id}"]
          else
            add_edge ~tag:name [%string "%{source_upstream} --> %{action_id}"];
          add_edge ~tag:name [%string "%{action_id} --> %{node_id_of_kind Headers}"]
      | Build_lib ->
          if has_configure then
            add_edge ~tag:name [%string "A_configure --> %{action_id}"]
          else
            add_edge ~tag:name [%string "%{source_upstream} --> %{action_id}"];
          (* When lib is expanded, build_lib produces the build_tree variant *)
          let lib_dest =
            if is_expanded Lib
               && List.exists (expand_vars ()) ~f:(fun (v,_) -> String.equal v "build_tree")
            then expand_variant_nid Lib "build_tree"
            else kind_nid Lib
          in
          add_edge ~tag:name [%string "%{action_id} --> %{lib_dest}"]
      | Build_binding lang ->
          if has_configure then
            add_edge ~tag:name [%string "A_configure --> %{action_id}"];
          add_edge ~tag:name
            [%string "%{kind_nid Headers} -.->|headers| %{action_id}"];
          add_edge ~tag:name [%string "%{kind_nid Lib} -.->|link| %{action_id}"];
          add_edge ~tag:name [%string "%{action_id} --> %{kind_nid (Binding lang)}"]
      | Build_app ->
          let app_binding_nid =
            match List.find_map rules ~f:(fun r ->
                match r with Build_binding lang -> Some lang | _ -> None) with
            | Some lang -> kind_nid (Binding lang)
            | None -> kind_nid (Binding OCaml)
          in
          add_edge ~tag:name [%string "%{app_binding_nid} --> %{action_id}"];
          add_edge ~tag:name [%string "%{kind_nid Lib} -.->|link| %{action_id}"];
          add_edge ~tag:name [%string "%{action_id} --> %{kind_nid App}"]
      | _ -> ());
  (* Install edges: build → install.
     When lib is expanded, route through build_tree/staged artifact nodes. *)
  List.iter install_rules ~f:(fun r ->
      let name = string_of_rule r in
      match r with
      | Install_lib ->
          let vs = expand_vars () in
          let has_var v = List.exists vs ~f:(fun (vi,_) -> String.equal vi v) in
          if is_expanded Lib && has_var "build_tree" then begin
            add_edge ~tag:name
              [%string "%{expand_variant_nid Lib \"build_tree\"} --> A_%{name}"];
            if has_var "staged" then
              add_edge ~tag:name
                [%string "A_%{name} --> %{expand_variant_nid Lib \"staged\"}"]
          end else
            add_edge ~tag:name [%string "A_build_lib --> A_%{name}"]
      | _ -> ());
  (* Publish edges: consumed variant → pack action → produced variant (if distinct) *)
  List.iter publish_kinds ~f:(fun kind ->
      let tag = string_of_rule (Publish kind) in
      add_edge ~tag [%string "%{kind_nid kind} --> A_%{tag}"];
      Option.iter (pack_produced_nid kind) ~f:(fun produced ->
          add_edge ~tag [%string "A_%{tag} --> %{produced}"]));
  (* Probe edges.
     Expanded probes emit one edge-set per variant.
     Non-expanded use the original logic (Binding+Publish routes through pack). *)
  List.iter probe_kinds ~f:(fun kind ->
      let base_tag = string_of_rule (Probe kind) in
      if is_probe_expanded kind then
        (* Expanded: one edge-set per probe step variant, routed through the
           matching artifact variant node when the artifact is also expanded. *)
        List.iter (probe_expand_items kind) ~f:(fun (probe_tag, variant_id, _label) ->
            let source_nid =
              if is_expanded kind
                 && List.exists (expand_vars ()) ~f:(fun (v,_) -> String.equal v variant_id)
              then expand_variant_nid kind variant_id
              else kind_nid kind
            in
            add_edge ~tag:probe_tag
              [%string "%{source_nid} -->|test| A_%{probe_tag}"];
            (match kind with
             | Binding _ | App ->
                 add_edge ~tag:probe_tag
                   [%string "%{kind_nid Lib} -.->|runtime| A_%{probe_tag}"]
             | _ -> ()))
      else begin
        (* Non-expanded: original logic *)
        (match kind with
         | Binding _ ->
             (* In the non-expanded overview, probe routes from the binding artifact
                pool node directly — the abstract rule is "test the binding", whether
                build_tree or packed.  Routing through the packed variant would falsely
                imply probe can't run until after pack. *)
             add_edge ~tag:base_tag [%string "%{kind_nid kind} -->|test| A_%{base_tag}"];
             add_edge ~tag:base_tag [%string "%{kind_nid Lib} -.->|runtime| A_%{base_tag}"]
         | App ->
             add_edge ~tag:base_tag [%string "%{kind_nid kind} -->|test| A_%{base_tag}"];
             add_edge ~tag:base_tag [%string "%{kind_nid Lib} -.->|runtime| A_%{base_tag}"]
         | _ ->
             add_edge ~tag:base_tag [%string "%{kind_nid kind} -->|test| A_%{base_tag}"])
      end);
  (* Summary edges: parent action → summary action.
     Dashed edge to signal "follow-up annotation" rather than data flow. *)
  List.iter summary_rules ~f:(fun (rule, suffix) ->
      if not (is_inlined_inspect rule) then
        List.iter (summary_item_triples rule suffix) ~f:(fun (nid, tag, parent_nid) ->
            add_edge ~tag [%string "%{parent_nid} -.-> %{nid}"]));
  add "";
  (* Styling *)
  add "    classDef artifact fill:#fff3e0,stroke:#ff9800,stroke-width:2px";
  add "    classDef action fill:#f3e5f5,stroke:#9c27b0,stroke-width:2px";
  add "    classDef st_done fill:#c8e6c9,stroke:#4caf50,stroke-width:3px";
  add "    classDef st_done_ctx fill:#e8f5e9,stroke:#a5d6a7,stroke-width:1.5px";
  add "    classDef st_expected_fail fill:#fff9c4,stroke:#f9a825,stroke-width:2px";
  add "    classDef st_failed fill:#ffcdd2,stroke:#c62828,stroke-width:2px";
  add "    classDef st_skipped fill:#f5f5f5,stroke:#9e9e9e,stroke-dasharray:5";
  add "    classDef st_nospec fill:#fafafa,stroke:#bdbdbd,stroke-dasharray:5";
  let all_artifact_nids =
    List.concat_map all_pool_kinds ~f:(fun kind ->
        if is_expanded kind then
          List.map (expand_vars ()) ~f:(fun (vid,_) -> expand_variant_nid kind vid)
        else [ node_id_of_kind kind ])
  in
  if not (List.is_empty all_artifact_nids) then
    add [%string "    class %{String.concat all_artifact_nids ~sep:\",\"} artifact"];
  (* action_entries: (node_id, status_tag) pairs for rendered action nodes.
     Fetch steps are embedded in artifact labels — not listed here. *)
  let scan_entries =
    if has_scan then [ (scan_nid, "scan_source") ] else []
  in
  let summary_entries =
    List.concat_map summary_rules ~f:(fun (rule, suffix) ->
        if is_inlined_inspect rule then []
        else List.map (summary_item_triples rule suffix) ~f:(fun (nid, tag, _) -> (nid, tag)))
  in
  let action_entries =
    scan_entries
    @ (if has_configure then [ ("A_configure", "configure") ] else [])
    @ List.map build_rules ~f:(fun r ->
          ([%string "A_%{string_of_rule r}"], string_of_rule r))
    @ List.map install_rules ~f:(fun r ->
          ([%string "A_%{string_of_rule r}"], string_of_rule r))
    @ List.map publish_kinds ~f:(fun k ->
          let name = string_of_rule (Publish k) in
          ([%string "A_%{name}"], name))
    @ List.concat_map probe_kinds ~f:(fun k ->
          if is_probe_expanded k then
            List.map (probe_expand_items k) ~f:(fun (probe_tag, _, _) ->
                ([%string "A_%{probe_tag}"], probe_tag))
          else
            let name = string_of_rule (Probe k) in
            [ ([%string "A_%{name}"], name) ])
    @ summary_entries
  in
  (match status with
   | None ->
       let action_ids = List.map action_entries ~f:fst in
       if not (List.is_empty action_ids) then
         add [%string "    class %{String.concat action_ids ~sep:\",\"} action"]
   | Some _ ->
       List.iter action_entries ~f:(fun (node_id, tag) ->
           let cls = match get_status tag with
             | Some Done ->
                 (match focal_predicate with
                  | None -> "st_done"
                  | Some pred -> if pred tag then "st_done" else "st_done_ctx")
             | Some Done_fail -> "st_expected_fail"
             | Some Failed -> "st_failed"
             | Some Skipped -> "st_skipped"
             | Some Not_in_spec | None -> "st_nospec"
           in
           add [%string "    class %{node_id} %{cls}"]));
  (match status with
   | None -> ()
   | Some _ ->
       List.iter (List.rev !edge_tags) ~f:(fun (idx, tag) ->
           let style = match get_status tag with
             | Some Done -> Some "stroke:#4caf50,stroke-width:3px"
             | Some Done_fail -> Some "stroke:#f9a825,stroke-width:3px"
             | Some Failed -> Some "stroke:#ef5350,stroke-width:3px"
             | Some Skipped -> Some "stroke:#9e9e9e,stroke-width:1px,stroke-dasharray:5"
             | Some Not_in_spec | None -> Some "stroke:#bdbdbd,stroke-width:1px,stroke-dasharray:5"
           in
           Option.iter style ~f:(fun s ->
               add [%string "    linkStyle %{Int.to_string idx} %{s}"])));
  Buffer.contents buf


(* ── Result diagram ──
   Reuses the action_rule schema diagram, colored by run status. *)

let result_status_of_run (steps : action_step list)
    (run_status : (string, step_status) Hashtbl.t) =
  let open Canary in
  let tbl = Hashtbl.create (module String) in
  (* Mark all store_rules actions as Not_in_spec initially.
     Use OCaml as sentinel lang — langs are fully known from steps. *)
  let langs =
    List.filter_map steps ~f:(fun s ->
        match s.rule with
        | Build_binding lang | Fetch (Binding lang)
        | Publish (Binding lang) | Probe (Binding lang) -> Some lang
        | _ -> None)
    |> List.dedup_and_sort ~compare:Poly.compare
    |> fun ls -> if List.is_empty ls then Canary_lang.[ OCaml ] else ls
  in
  List.iter (store_rules ~langs) ~f:(fun r ->
      Hashtbl.set tbl ~key:(string_of_rule r) ~data:Not_in_spec);
  (* Override with actual run results.
     Also update the canonical rule tag for split probes: probe_binding_pkg/pip
     have tag ≠ string_of_rule, so merge them into "probe_binding" using
     Done > Failed > Skipped precedence so the diagram node reflects reality. *)
  let merge_status prev ns =
    let open Canary in
    match prev with
    | None | Some Not_in_spec | Some Skipped -> ns
    | Some Done -> Done
    | Some Done_fail -> (match ns with Done -> Done | Failed -> Failed | _ -> Done_fail)
    | Some Failed -> (match ns with Done -> Done | _ -> Failed)
  in
  List.iter steps ~f:(fun s ->
      let ns = match Hashtbl.find run_status s.tag with
        | Some Step_done ->
            (match s.expectation with
             | Expect_failure _ | Expect_compat_failure _ -> Done_fail
             | Expect_success -> Done)
        | Some Step_failed -> Failed
        | Some Step_skipped -> Skipped
        | None -> Skipped
      in
      Hashtbl.set tbl ~key:s.tag ~data:ns;
      let canonical = string_of_rule s.rule in
      if not (String.equal s.tag canonical) then
        Hashtbl.update tbl canonical ~f:(fun prev -> merge_status prev ns));
  tbl

(* ── Step-based Mermaid renderer (per-view diagrams) ──
   Renders a (possibly filtered) action_step list. Each step becomes a
   node; edges follow step.deps within the rendered subset.
   Caller filters before calling — use [mermaid_of_steps_for_view] for
   the canned view filters defined in this module. *)

let _node_shape_of_rule rule =
  match rule with
  | Probe _                                  -> `Pill
  | Build_lib | Build_binding _ | Build_app
  | Build_headers | Configure | Scan_sources | Install_lib
  | Publish _                                -> `Hex
  | Fetch _                                  -> `Box

let mermaid_node_for_step ~id ~is_inspect ~is_scan (s : action_step) =
  let nid = "S_" ^ s.tag in
  let label = [%string "%{s.tag} [%{Int.to_string id}]"] in
  let shape =
    if is_inspect || is_scan then `Pill
    else _node_shape_of_rule s.rule
  in
  let line = match shape with
    | `Pill -> [%string "    %{nid}([\"%{label}\"])"]
    | `Hex  -> [%string "    %{nid}{{\"%{label}\"}}"]
    | `Box  -> [%string "    %{nid}[\"%{label}\"]"]
  in
  (nid, line)

let _is_inspect_step (s : action_step) =
  String.is_suffix s.tag ~suffix:"_inspect"
let _is_scan_step (s : action_step) =
  String.equal s.tag "scan_source"

(* Stable per-step index based on execution order (1-based).
   Same id is used across overview and detail views so users can
   cross-reference between diagrams and the action log. *)
let step_id_table (all_steps : action_step list) : (string, int) Hashtbl.t =
  let tbl = Hashtbl.create (module String) in
  List.iteri all_steps ~f:(fun i s ->
      Hashtbl.set tbl ~key:s.tag ~data:(i + 1));
  tbl

(* Render a filtered action_step list as a Mermaid graph. [all_steps]
   gives the full step list (used for stable ID assignment); only the
   subset for which [filter] returns true is rendered. Deps that point
   outside the subset are silently dropped. [status] (optional) maps
   each step.tag to a Canary.node_status to color the nodes. *)
let mermaid_of_steps
    ?(status : (string, Canary.node_status) Hashtbl.t option)
    ?(title : string option)
    ~(all_steps : action_step list)
    ?(filter : (action_step -> bool) option)
    () : string =
  let ids = step_id_table all_steps in
  let id_of s = Hashtbl.find_exn ids s.tag in
  let pred = Option.value filter ~default:(fun _ -> true) in
  let steps = List.filter all_steps ~f:pred in
  let buf = Buffer.create 1024 in
  let add s = Buffer.add_string buf s; Buffer.add_char buf '\n' in
  Option.iter title ~f:(fun t -> add ("%% " ^ t));
  add "graph LR";
  let in_subset = Hash_set.create (module String) in
  List.iter steps ~f:(fun s -> Hash_set.add in_subset s.tag);
  let edge_idx = ref 0 in
  let edge_tags = ref [] in
  let add_edge ~src ~dst ~tag ~dashed =
    let arrow = if dashed then "-.->" else "-->" in
    add [%string "    %{src} %{arrow} %{dst}"];
    edge_tags := (!edge_idx, tag) :: !edge_tags;
    Int.incr edge_idx
  in
  (* Nodes *)
  List.iter steps ~f:(fun s ->
      let is_inspect = _is_inspect_step s in
      let is_scan = _is_scan_step s in
      let (_, line) =
        mermaid_node_for_step ~id:(id_of s) ~is_inspect ~is_scan s
      in
      add line);
  add "";
  (* Edges *)
  List.iter steps ~f:(fun s ->
      let dst = "S_" ^ s.tag in
      let dashed = _is_inspect_step s || _is_scan_step s in
      List.iter s.deps ~f:(fun dep ->
          if Hash_set.mem in_subset dep then
            add_edge ~src:("S_" ^ dep) ~dst ~tag:s.tag ~dashed));
  add "";
  (* Styling *)
  add "    classDef st_done fill:#c8e6c9,stroke:#4caf50,stroke-width:3px";
  add "    classDef st_expected_fail fill:#fff9c4,stroke:#f9a825,stroke-width:2px";
  add "    classDef st_failed fill:#ffcdd2,stroke:#c62828,stroke-width:2px";
  add "    classDef st_skipped fill:#f5f5f5,stroke:#9e9e9e,stroke-dasharray:5";
  add "    classDef st_nospec fill:#fafafa,stroke:#bdbdbd,stroke-dasharray:5";
  (match status with
   | None -> ()
   | Some tbl ->
       List.iter steps ~f:(fun s ->
           let cls = match Hashtbl.find tbl s.tag with
             | Some Canary.Done -> "st_done"
             | Some Canary.Done_fail -> "st_expected_fail"
             | Some Canary.Failed -> "st_failed"
             | Some Canary.Skipped -> "st_skipped"
             | Some Canary.Not_in_spec | None -> "st_nospec"
           in
           add [%string "    class S_%{s.tag} %{cls}"]));
  Buffer.contents buf

(* ── Canned view filters ── *)

type view = [
  | `Source
  | `Lib
  | `Binding of Canary_lang.lang
  | `Probes
  | `Pack
  | `Full
]

let view_name : view -> string = function
  | `Source -> "source"
  | `Lib -> "lib"
  | `Binding lang -> "binding_" ^ Canary_lang.string_of_lang lang
  | `Probes -> "probes"
  | `Pack -> "pack"
  | `Full -> "full"

let focal_tag_pred (v : view) (tag : string) : bool =
  match v with
  | `Source ->
      String.equal tag "fetch_source" || String.equal tag "scan_source"
  | `Lib ->
      String.equal tag "fetch_lib"
      || String.equal tag "build_lib"
      || String.equal tag "install_lib"
      || String.is_prefix tag ~prefix:"probe_lib"
  | `Binding lang ->
      let lang_str = Canary_lang.string_of_lang lang in
      String.is_substring tag ~substring:("binding_" ^ lang_str)
  | `Probes -> String.is_prefix tag ~prefix:"probe_"
  | `Pack -> String.is_prefix tag ~prefix:"pack_"
  | `Full -> true

let view_predicate (v : view) (s : action_step) : bool =
  match v with
  | `Source ->
      String.equal s.tag "fetch_source" || String.equal s.tag "scan_source"
  | `Lib ->
      String.equal s.tag "fetch_lib"
      || String.equal s.tag "build_lib"
      || String.equal s.tag "install_lib"
      || String.is_prefix s.tag ~prefix:"probe_lib"
  | `Binding lang ->
      let lang_str = Canary_lang.string_of_lang lang in
      String.is_substring s.tag ~substring:("binding_" ^ lang_str)
  | `Probes ->
      String.is_prefix s.tag ~prefix:"probe_"
  | `Pack ->
      String.is_prefix s.tag ~prefix:"pack_"
  | `Full -> true

(* ── Artifact-aware detail renderers ──
   The basic view filter (mermaid_of_steps + view_predicate) shows step
   nodes only. The detail renderers below add artifact pool nodes per
   variant — e.g. lib(build_tree), lib(staged), lib(apt) — so each
   (artifact, store) instance is its own node and the variant-specific
   action chain is visible. Used for the lib + binding tabs in the HTML
   viewer. *)

let _id_label_for ~ids tag =
  match Hashtbl.find ids tag with
  | Some n -> [%string "%{tag} [%{Int.to_string n}]"]
  | None -> tag

(* Variant tag derived from a probe_<X> step tag.
   - probe_lib              → "default"
   - probe_lib_apt          → "apt"
   - probe_lib_staged       → "staged"
   - probe_lib_build_tree   → "build_tree"
   - probe_binding_ocaml    → "default"
   - probe_binding_ocaml_opam → "opam"
   etc. *)
let _variant_of_probe_tag ~prefix tag =
  if String.equal tag prefix then "default"
  else
    match String.chop_prefix tag ~prefix:(prefix ^ "_") with
    | Some suffix -> suffix
    | None -> "default"

(* Determine the "default" variant alias.
   - If there's a build_<artifact> step → primary is build_tree.
   - Else if there's a fetch step → primary is whatever PM (apt/brew/opam/pip).
   - Else just "default". *)
let _default_variant_alias ~all_steps ~build_tag ~fetch_tag ~variants =
  let has_step t = List.exists all_steps ~f:(fun s -> String.equal s.tag t) in
  if has_step build_tag then "build_tree"
  else if has_step fetch_tag then begin
    (* Pick the PM-like variant if exactly one is present. Otherwise fall
       back to a generic "fetch" alias (better than "default" — at least
       names the producer). *)
    let pm_like = List.filter variants ~f:(fun v ->
        not (String.equal v "default")
        && not (String.equal v "build_tree")
        && not (String.equal v "staged")) in
    match pm_like with
    | [ v ] -> v
    | _ -> "fetch"
  end
  else "default"


(* Compute the expand_probe_kinds parameter for mermaid_of_action_rule_schema.
   Returns per-probe-step (probe_tag, resolved_variant_id, label) triples.
   variant_id matches the variant_id computed by _compute_expand for the same
   artifact kind, so edges route correctly to the expanded artifact nodes. *)
let _compute_probe_expand
    ~(artifact_kind : artifact_kind)
    ~(probe_prefix : string)
    ~(build_tag : string)
    ~(fetch_tag : string)
    ~(step_ids : (string, int) Hashtbl.t)
    (steps : action_step list)
  : (artifact_kind * (string * string * string) list) option =
  let probe_steps = List.filter steps ~f:(fun s ->
      not (String.is_suffix s.tag ~suffix:"_inspect")
      && (String.equal s.tag probe_prefix
          || String.is_prefix s.tag ~prefix:(probe_prefix ^ "_")))
  in
  if List.is_empty probe_steps then None
  else begin
    let variants =
      List.map probe_steps ~f:(fun s -> _variant_of_probe_tag ~prefix:probe_prefix s.tag)
      |> List.dedup_and_sort ~compare:String.compare
    in
    let default_alias =
      _default_variant_alias ~all_steps:steps ~build_tag ~fetch_tag ~variants
    in
    let items = List.map probe_steps ~f:(fun s ->
        let raw_vid = _variant_of_probe_tag ~prefix:probe_prefix s.tag in
        let variant_id = if String.equal raw_vid "default" then default_alias else raw_vid in
        let id_part = match Hashtbl.find step_ids s.tag with
          | Some n -> [%string " [%{Int.to_string n}]"]
          | None -> ""
        in
        (* Use the concrete step tag (e.g. probe_lib_apt) not the rule name (probe_lib),
           so each expanded node is uniquely identified by its actual action. *)
        (s.tag, variant_id, s.tag ^ id_part))
    in
    Some (artifact_kind, items)
  end

(* Shared helper: infer PM name from a fetch/pack step tag and its base prefix. *)
let _fetch_pm_of_tag kind tag =
  let base = string_of_rule (Fetch kind) in
  match String.chop_prefix tag ~prefix:(base ^ "_") with
  | Some s -> s
  | None -> (match kind with
      | Source -> "git"
      | Lib -> "apt"
      | Binding Canary_lang.OCaml -> "opam"
      | Binding Canary_lang.Python -> "pip"
      | _ -> "pkg")

(* Shared helper: version string for an (artifact_kind, artifact_variant_id) pair.
   artifact_variant_id is one of "build_tree", "staged", or a PM name ("apt",
   "opam", "pip", …).  variant_infos = [(run_id, version, actions)] from
   run_info.json.  Returns None when no version can be determined. *)
let _art_variant_version ~variant_infos ~steps kind vid =
  let has_step t = List.exists steps ~f:(fun s -> String.equal s.tag t) in
  let version_of_run_id rid =
    match List.find variant_infos ~f:(fun (i, _, _) -> String.equal i rid) with
    | Some (_, v, _) -> Some v | None -> None
  in
  let pm_fetch_version fetch_tag =
    let candidates = List.filter variant_infos ~f:(fun (_, _, acts) ->
        List.mem acts fetch_tag ~equal:String.equal) in
    match List.find candidates ~f:(fun (_, v, _) -> not (String.equal v "dev")) with
    | Some (_, v, _) -> Some v
    | None -> (match candidates with (_, v, _) :: _ -> Some v | [] -> None)
  in
  match vid with
  | "build_tree" ->
      let s = List.find steps ~f:(fun s -> match kind, s.rule with
          | Lib, Build_lib | Headers, Build_headers | App, Build_app -> true
          | Binding l, Build_binding l2 -> Poly.equal l l2
          | _ -> false) in
      Option.bind s ~f:(fun s -> version_of_run_id s.variant_id)
  | "staged" ->
      let s = List.find steps ~f:(fun s ->
          match s.rule with Install_lib -> true | _ -> false) in
      Option.bind s ~f:(fun s -> version_of_run_id s.variant_id)
  | pm ->
      let via_pack = List.find steps ~f:(fun s ->
          (match s.rule with Publish k -> Poly.equal k kind | _ -> false)
          && String.equal (_fetch_pm_of_tag kind s.tag) pm) in
      (match via_pack with
       | Some s -> version_of_run_id s.variant_id
       | None ->
           let fetch_tag = string_of_rule (Fetch kind) in
           let fetch_tag_pm = fetch_tag ^ "_" ^ pm in
           let tag = if has_step fetch_tag_pm then fetch_tag_pm else fetch_tag in
           pm_fetch_version tag)

(* Compute the expand_artifact parameter for mermaid_of_action_rule_schema.
   Derives per-variant (variant_id, label) pairs from the actual probe steps.
   Returns None when no probe steps for the artifact are found.
   Labels include real artifact names, version strings, and the producer step's
   [N] ID (e.g. "libz3.so (dev) [5]" for build_lib, "libz3.so (4.15.2) [7]" for
   fetch_lib). *)
let _compute_expand
    ~(artifact_kind : artifact_kind)
    ~(probe_prefix : string)
    ~(build_tag : string)
    ~(fetch_tag : string)
    ~(artifact_names : artifact_kind -> string option)
    ~(variant_infos : (string * string * string list) list)
    ~(label_kind : string)
    ~(step_ids : (string, int) Hashtbl.t)
    (steps : action_step list)
  : (artifact_kind * (string * string) list) option =
  let probe_steps = List.filter steps ~f:(fun s ->
      not (String.is_suffix s.tag ~suffix:"_inspect")
      && (String.equal s.tag probe_prefix
          || String.is_prefix s.tag ~prefix:(probe_prefix ^ "_")))
  in
  if List.is_empty probe_steps then None
  else begin
    let variants =
      List.map probe_steps ~f:(fun s ->
          _variant_of_probe_tag ~prefix:probe_prefix s.tag)
      |> List.dedup_and_sort ~compare:String.compare
    in
    let default_alias =
      _default_variant_alias ~all_steps:steps ~build_tag ~fetch_tag ~variants
    in
    (* Find the step ID of the producer for a resolved variant. *)
    let producer_id resolved_vid =
      let tag =
        if String.equal resolved_vid "build_tree" then Some build_tag
        else if String.equal resolved_vid "staged" then Some "install_lib"
        else begin
          (* PM variant: check pack first (Binding opam/pip from pack_binding),
             then fetch step. *)
          let pack_tag = match artifact_kind with
            | Binding lang ->
                let t = "pack_binding_" ^ Canary_lang.string_of_lang lang in
                if List.exists steps ~f:(fun s -> String.equal s.tag t) then Some t else None
            | Lib ->
                let t = "pack_lib" in
                if List.exists steps ~f:(fun s -> String.equal s.tag t) then Some t else None
            | _ -> None
          in
          let from_pack = match pack_tag, artifact_kind with
            | Some pt, Binding Canary_lang.OCaml when String.equal resolved_vid "opam" -> Some pt
            | Some pt, Binding Canary_lang.Python when String.equal resolved_vid "pip" -> Some pt
            | _ -> None
          in
          match from_pack with
          | Some _ as s -> s
          | None ->
              let fetch_base = string_of_rule (Fetch artifact_kind) in
              let cand =
                if String.equal resolved_vid fetch_tag then fetch_tag
                else fetch_base ^ "_" ^ resolved_vid
              in
              if List.exists steps ~f:(fun s -> String.equal s.tag cand)
              then Some cand
              else Some fetch_tag
        end
      in
      match tag with
      | Some t -> (match Hashtbl.find step_ids t with Some n -> [%string " [%{Int.to_string n}]"] | None -> "")
      | None -> ""
    in
    let base_name = Option.value (artifact_names artifact_kind) ~default:label_kind in
    let multi = List.length variants > 1 in
    let variant_pairs =
      List.map variants ~f:(fun v ->
          let rv = if String.equal v "default" then default_alias else v in
          let ver = _art_variant_version ~variant_infos ~steps artifact_kind rv in
          let label = match ver with
            | Some version -> [%string "%{base_name} (%{version})%{producer_id rv}"]
            | None -> if multi then [%string "%{base_name} (%{rv})%{producer_id rv}"]
                      else base_name ^ producer_id rv
          in
          (rv, label))
    in
    Some (artifact_kind, variant_pairs)
  end

(* ── Full view renderer ────────────────────────────────────────────────────
   Every step is an individual action node.  Artifact kinds are grouped in
   subgraphs; PM-sourced variants get a store cylinder node upstream of the
   fetch action.  Source→configure is chained through scan_source when present
   (chain_scan = true for this view). *)
let mermaid_full
    ?(status : (string, node_status) Hashtbl.t option)
    ?(view_title = "full")
    ~step_ids
    ~has_scan
    ~(summary_rules : (rule * string) list)
    ~(variant_infos : (string * string * string list) list)
    ~(artifact_names : artifact_kind -> string option)
    (steps : action_step list) : string =
  ignore summary_rules;
  let buf = Buffer.create 2048 in
  let add s = Buffer.add_string buf s; Buffer.add_char buf '\n' in
  let has_step t = List.exists steps ~f:(fun s -> String.equal s.tag t) in
  let id_label tag =
    let disp =
      if String.is_suffix tag ~suffix:"_inspect"
      then inspect_label_of_tag tag else tag
    in
    match Hashtbl.find step_ids tag with
    | Some n -> [%string "%{disp} [%{Int.to_string n}]"]
    | None -> disp
  in
  (* ── Kind utilities ── *)
  let kind_str k = string_of_artifact_kind k in
  let kind_label = function
    | Source -> "source" | Headers -> "headers" | Lib -> "lib"
    | Binding lang -> Canary_lang.string_of_lang lang ^ " binding"
    | App -> "app"
  in
  (* Artifact docs node id for (kind, variant_id).  Single-variant uses canonical. *)
  let art_nid k vid = [%string "%{kind_str k}_%{vid}_node"] in
  let art_nid_canonical k = [%string "%{kind_str k}_node"] in
  let fetch_pm kind tag = _fetch_pm_of_tag kind tag
  in
  (* For a kind, collect its variants as (variant_id, docs_node_id) pairs and
     the associated fetch steps. Build variants precede fetch variants.
     Single-variant kinds use the canonical node id so edges stay clean. *)
  let kind_variants kind =
    let build_tag = match kind with
      | Lib -> if has_step "build_lib" then Some "build_lib" else None
      | Headers -> if has_step "build_headers" then Some "build_headers" else None
      | Binding lang ->
          let t = "build_binding_" ^ Canary_lang.string_of_lang lang in
          if has_step t then Some t else None
      | App -> if has_step "build_app" then Some "build_app" else None
      | Source -> None
    in
    let install = Poly.equal kind Lib && has_step "install_lib" in
    let fetch_base = string_of_rule (Fetch kind) in
    let fetch_steps = List.filter steps ~f:(fun s ->
        not (String.is_suffix s.tag ~suffix:"_inspect")
        && (String.equal s.tag fetch_base
            || String.is_prefix s.tag ~prefix:(fetch_base ^ "_")))
    in
    (* PM variant produced by pack_<kind> step, if any.
       pack produces an opam/pip artifact that is a distinct variant from build_tree. *)
    let pack_pm =
      let pack_t = match kind with
        | Binding lang -> "pack_binding_" ^ Canary_lang.string_of_lang lang
        | Lib -> "pack_lib"
        | _ -> ""
      in
      if (not (String.is_empty pack_t)) && has_step pack_t then
        Some (match kind with
          | Binding Canary_lang.OCaml -> "opam"
          | Binding Canary_lang.Python -> "pip"
          | _ -> fetch_pm kind pack_t)
      else None
    in
    let vs = ref [] in
    Option.iter build_tag ~f:(fun _ -> vs := ("build_tree", ()) :: !vs);
    if install then vs := ("staged", ()) :: !vs;
    List.iter fetch_steps ~f:(fun fs ->
        let pm = fetch_pm kind fs.tag in
        vs := (pm, ()) :: !vs);
    Option.iter pack_pm ~f:(fun pm -> vs := (pm, ()) :: !vs);
    let seen = Hash_set.create (module String) in
    let raw = List.filter_map (List.rev !vs) ~f:(fun (v, ()) ->
        if Hash_set.mem seen v then None
        else (Hash_set.add seen v; Some v))
    in
    (* Resolve final node ids: canonical for single-variant, variant-based for multi *)
    let variants = match raw with
      | [v] -> [(v, art_nid_canonical kind)]
      | _ -> List.map raw ~f:(fun v -> (v, art_nid kind v))
    in
    (variants, fetch_steps, build_tag, install)
  in
  (* Primary node id used for cross-kind runtime/link edges. *)
  let primary_nid kind variants =
    let pref = ["build_tree"; "staged"; "git"] in
    match List.find pref ~f:(fun p -> List.exists variants ~f:(fun (v, _) -> String.equal v p)) with
    | Some v ->
        (* Use canonical for single-variant, variant-based for multi *)
        (match variants with [_] -> art_nid_canonical kind | _ -> art_nid kind v)
    | None -> (match variants with (_, n) :: _ -> n | [] -> art_nid_canonical kind)
  in
  (* Which artifact kinds have any step? *)
  let binding_langs =
    List.filter_map steps ~f:(fun s -> match s.rule with
        | Fetch (Binding l) | Probe (Binding l) | Publish (Binding l)
        | Build_binding l -> Some l | _ -> None)
    |> List.dedup_and_sort ~compare:Poly.compare
  in
  let all_kinds = [Source; Headers; Lib] @ List.map binding_langs ~f:(fun l -> Binding l) @ [App] in
  let kind_has_steps k =
    List.exists steps ~f:(fun s ->
        match s.rule with
        | Fetch k2 | Probe k2 | Publish k2 -> Poly.equal k k2
        | Build_lib -> Poly.equal k Lib | Install_lib -> Poly.equal k Lib
        | Build_headers -> Poly.equal k Headers
        | Build_binding l -> Poly.equal k (Binding l) | Build_app -> Poly.equal k App
        | Configure | Scan_sources -> Poly.equal k Source)
  in
  let present_kinds = List.filter all_kinds ~f:kind_has_steps in
  (* Compute variant info for every present kind upfront *)
  let kind_data =
    List.map present_kinds ~f:(fun k -> (k, kind_variants k))
  in
  add [%string "%% view: %{view_title}"];
  add "graph LR";
  let version_of_art_variant kind vid =
    _art_variant_version ~variant_infos ~steps kind vid
  in
  (* Source variant: always annotate with the version of whichever run fetched it. *)
  let source_version = _art_variant_version ~variant_infos ~steps Source "git" in
  (* Variants that are "products" of our build/pack pipeline (not inputs from outside).
     lib: "staged" = output of install_lib.
     binding: packed pm variant = output of pack_binding (opam for OCaml, pip for Python). *)
  let product_vids_of_kind kind =
    match kind with
    | Lib -> if has_step "install_lib" then [ "staged" ] else []
    | Binding lang ->
        let pack_t = "pack_binding_" ^ Canary_lang.string_of_lang lang in
        if has_step pack_t then
          [ (match lang with
             | Canary_lang.OCaml -> "opam"
             | Canary_lang.Python -> "pip"
             | _ -> fetch_pm (Binding lang) pack_t) ]
        else []
    | _ -> []
  in
  (* ── Subgraphs: one or two per artifact kind ──
     When a kind has both input variants (fetched/built) and product variants
     (installed/packed), split into separate subgraphs for clarity. *)
  List.iter kind_data ~f:(fun (kind, (variants, _, _, _)) ->
      let lbl = kind_label kind in
      let product_vids = product_vids_of_kind kind in
      let input_vs = List.filter variants ~f:(fun (v, _) ->
          not (List.mem product_vids v ~equal:String.equal)) in
      let product_vs = List.filter variants ~f:(fun (v, _) ->
          List.mem product_vids v ~equal:String.equal) in
      let has_split = not (List.is_empty product_vs) in
      let multi = List.length variants > 1 || has_split in
      (* Real artifact name (e.g. "libz3.so") when provided; falls back to kind label. *)
      let base_name =
        if Poly.equal kind Source then "source"
        else Option.value (artifact_names kind) ~default:lbl
      in
      (* Emit doc nodes.  Label = base_name (version).  When there is only one
         variant and no split, omit the parenthesised suffix if no version known. *)
      let emit_nodes vs =
        List.iter vs ~f:(fun (vid, n) ->
            let ver = match kind with
              | Source -> source_version
              | _ -> version_of_art_variant kind vid
            in
            let node_lbl = match ver with
              | Some v -> [%string "%{base_name} (%{v})"]
              | None   -> if multi then [%string "%{base_name} (%{vid})"] else base_name
            in
            add [%string "      %{n}@{ shape: doc, label: \"%{node_lbl}\" }"])
      in
      if has_split then begin
        (* Input subgraph: fetched from PM + built from source *)
        let sg_in = [%string "%{kind_str kind}_input_sg"] in
        add [%string "    subgraph %{sg_in} [\"%{lbl}\"]"];
        (if List.is_empty input_vs then
           let n = art_nid_canonical kind in
           add [%string "      %{n}@{ shape: doc, label: \"%{base_name}\" }"]
         else emit_nodes input_vs);
        add "    end";
        (* Product subgraph: output of install_lib or pack_binding *)
        let sg_out = [%string "%{kind_str kind}_product_sg"] in
        let product_lbl = match kind with
          | Lib -> lbl ^ " (product)"
          | _ ->
              let pm = match product_vs with (v, _) :: _ -> v | [] -> "packed" in
              lbl ^ " (" ^ pm ^ ")"
        in
        add [%string "    subgraph %{sg_out} [\"%{product_lbl}\"]"];
        emit_nodes product_vs;
        add "    end"
      end else begin
        let sg = [%string "%{kind_str kind}_sg"] in
        add [%string "    subgraph %{sg} [\"%{lbl}\"]"];
        (match variants with
         | [] ->
             let n = art_nid_canonical kind in
             add [%string "      %{n}@{ shape: doc, label: \"%{base_name}\" }"]
         | _ -> emit_nodes variants);
        add "    end"
      end);
  add "";
  (* ── Store nodes (cylinder): one per unique PM across all fetch steps ── *)
  let stores =
    List.concat_map kind_data ~f:(fun (kind, (_, fsteps, _, _)) ->
        List.map fsteps ~f:(fun fs -> fetch_pm kind fs.tag))
    |> List.dedup_and_sort ~compare:String.compare
  in
  List.iter stores ~f:(fun pm ->
      add [%string "    %{pm}_store@{ shape: cyl, label: \"%{pm}\" }"]);
  if not (List.is_empty stores) then add "";
  (* ── Action nodes ── *)
  (* scan_source *)
  if has_scan then
    add [%string "    A_scan_source{{\"%{id_label \"scan_source\"}\"}}"];
  (* configure *)
  if has_step "configure" then
    add [%string "    A_configure{{\"%{id_label \"configure\"}\"}}"];
  (* Fetch steps as hexagon action nodes *)
  List.iter kind_data ~f:(fun (_, (_, fsteps, _, _)) ->
      List.iter fsteps ~f:(fun fs ->
          add [%string "    A_%{fs.tag}{{\"%{id_label fs.tag}\"}}"] ));
  (* Build / install / pack / probe / summary steps.
     Fetch steps (non-summary) are already emitted above as hexagons; summary
     steps for fetch rules fall through here so they get a pill node. *)
  let is_fetch_or_follow s =
    not (String.is_suffix s.tag ~suffix:"_inspect")
    && ((match s.rule with Fetch _ -> true | _ -> false)
        || String.equal s.tag "scan_source"
        || String.equal s.tag "configure")
  in
  List.iter steps ~f:(fun s ->
      if not (is_fetch_or_follow s) then begin
        let nid = "A_" ^ s.tag in
        let lbl = id_label s.tag in
        let line = match s.rule with
          | Probe _ -> [%string "    %{nid}([\"%{lbl}\"])"]
          | _ when String.is_suffix s.tag ~suffix:"_inspect" ->
              [%string "    %{nid}([\"%{lbl}\"])"]
          | _ -> [%string "    %{nid}{{\"%{lbl}\"}}"]
        in
        add line
      end);
  add "";
  (* ── Edges ── *)
  let edge_idx = ref 0 in
  let edge_tags = ref [] in
  let add_edge ?tag s =
    add [%string "    %{s}"];
    (match tag with Some t -> edge_tags := (!edge_idx, t) :: !edge_tags | None -> ());
    Int.incr edge_idx
  in
  (* Source fetch → source artifact → scan (annotation) → configure (chain) *)
  let src_variants =
    match List.find kind_data ~f:(fun (k, _) -> Poly.equal k Source) with
    | Some (_, (vs, _, _, _)) -> vs | None -> []
  in
  let src_n = match src_variants with (_, n) :: _ -> n | [] -> art_nid_canonical Source in
  if has_step "fetch_source" then
    add_edge ~tag:"fetch_source" [%string "git_store --> A_fetch_source --> %{src_n}"];
  if has_scan then
    add_edge ~tag:"scan_source" [%string "%{src_n} -.-> A_scan_source"];
  let src_upstream = if has_scan then "A_scan_source" else src_n in
  if has_step "configure" then
    add_edge ~tag:"configure" [%string "%{src_upstream} --> A_configure"];
  (* Per-kind build / install / fetch edges *)
  List.iter kind_data ~f:(fun (kind, (variants, fsteps, build_tag, install)) ->
      if Poly.equal kind Source then ()  (* handled above *)
      else begin
        let primary = primary_nid kind variants in
        let configure_up =
          if has_step "configure" then "A_configure" else
            (match List.find kind_data ~f:(fun (k, _) -> Poly.equal k Source) with
             | Some (_, (vs, _, _, _)) ->
                 (match vs with (_, n) :: _ -> n | [] -> art_nid_canonical Source)
             | None -> art_nid_canonical Source)
        in
        (* Resolve variant id → node id using the pre-computed variants list. *)
        let lookup_nid vid =
          match List.find variants ~f:(fun (v, _) -> String.equal v vid) with
          | Some (_, n) -> n
          | None -> primary
        in
        (* build_<kind> → artifact(build_tree) *)
        Option.iter build_tag ~f:(fun bt ->
            let build_nid = lookup_nid "build_tree" in
            if has_step "configure" then
              add_edge ~tag:bt [%string "A_configure --> A_%{bt}"]
            else
              add_edge ~tag:bt [%string "%{configure_up} --> A_%{bt}"];
            (* Binding builds also need headers + lib link edges *)
            (match kind with
             | Binding _ ->
                 let hdr_n =
                   match List.find kind_data ~f:(fun (k, _) -> Poly.equal k Headers) with
                   | Some (_, (hvs, _, _, _)) ->
                       (match hvs with (_, n) :: _ -> n | [] -> art_nid_canonical Headers)
                   | None -> art_nid_canonical Headers
                 in
                 let lib_n =
                   match List.find kind_data ~f:(fun (k, _) -> Poly.equal k Lib) with
                   | Some (_, (lvs, _, _, _)) -> primary_nid Lib lvs
                   | None -> art_nid_canonical Lib
                 in
                 add_edge ~tag:bt [%string "%{hdr_n} -.->|headers| A_%{bt}"];
                 add_edge ~tag:bt [%string "%{lib_n} -.->|link| A_%{bt}"]
             | _ -> ());
            add_edge ~tag:bt [%string "A_%{bt} --> %{build_nid}"]);
        (* install_lib: build_tree → install_lib → staged *)
        if install then begin
          add_edge ~tag:"install_lib" [%string "%{lookup_nid \"build_tree\"} --> A_install_lib"];
          add_edge ~tag:"install_lib" [%string "A_install_lib --> %{lookup_nid \"staged\"}"]
        end;
        (* store → fetch → artifact *)
        List.iter fsteps ~f:(fun fs ->
            let pm = fetch_pm kind fs.tag in
            let art = lookup_nid pm in
            add_edge ~tag:fs.tag [%string "%{pm}_store --> A_%{fs.tag} --> %{art}"];
            (* Binding fetch: lib runtime dep *)
            (match kind with
             | Binding _ ->
                 let lib_n = match List.find kind_data ~f:(fun (k, _) -> Poly.equal k Lib) with
                   | Some (_, (lvs, _, _, _)) -> primary_nid Lib lvs
                   | None -> art_nid_canonical Lib
                 in
                 add_edge ~tag:fs.tag [%string "%{lib_n} -.->|runtime| A_%{fs.tag}"]
             | _ -> ()));
        (* pack_<kind>: build_tree → pack → pm_variant *)
        let pack_tag = match kind with
          | Lib -> if has_step "pack_lib" then Some "pack_lib" else None
          | Binding lang ->
              let t = "pack_binding_" ^ Canary_lang.string_of_lang lang in
              if has_step t then Some t else None
          | App -> if has_step "pack_app" then Some "pack_app" else None
          | _ -> None
        in
        Option.iter pack_tag ~f:(fun pt ->
            let from_n = lookup_nid "build_tree" in
            add_edge ~tag:pt [%string "%{from_n} --> A_%{pt}"];
            (* Pack produces the pm variant (opam for binding, etc.) *)
            let pm_variant = List.find variants ~f:(fun (v, _) ->
                not (String.equal v "build_tree")
                && not (String.equal v "staged")
                && not (String.equal v "git")
                && not (String.equal v "pkg"))
            in
            Option.iter pm_variant ~f:(fun (_, pn) ->
                add_edge ~tag:pt [%string "A_%{pt} --> %{pn}"]));
        (* probe_<kind>_<variant> → from matching artifact variant *)
        let probe_base = string_of_rule (Probe kind) in
        let probe_steps = List.filter steps ~f:(fun s ->
            not (String.is_suffix s.tag ~suffix:"_inspect")
            && (String.equal s.tag probe_base
                || String.is_prefix s.tag ~prefix:(probe_base ^ "_")))
        in
        List.iter probe_steps ~f:(fun ps ->
            let vid = _variant_of_probe_tag ~prefix:probe_base ps.tag in
            let art = lookup_nid vid in
            add_edge ~tag:ps.tag [%string "%{art} -->|test| A_%{ps.tag}"];
            (* Binding + app probes: lib runtime dep *)
            (match kind with
             | Binding _ | App ->
                 let lib_n = match List.find kind_data ~f:(fun (k, _) -> Poly.equal k Lib) with
                   | Some (_, (lvs, _, _, _)) -> primary_nid Lib lvs
                   | None -> art_nid_canonical Lib
                 in
                 add_edge ~tag:ps.tag [%string "%{lib_n} -.->|runtime| A_%{ps.tag}"]
             | _ -> ()));
        (* build_app: from primary ocaml_binding + lib link *)
        if Poly.equal kind App then
          Option.iter build_tag ~f:(fun bt ->
              let ocaml_n = match List.find kind_data ~f:(fun (k, _) ->
                  Poly.equal k (Binding Canary_lang.OCaml)) with
                | Some (_, (bvs, _, _, _)) -> primary_nid (Binding Canary_lang.OCaml) bvs
                | None -> art_nid_canonical (Binding Canary_lang.OCaml)
              in
              let lib_n = match List.find kind_data ~f:(fun (k, _) -> Poly.equal k Lib) with
                | Some (_, (lvs, _, _, _)) -> primary_nid Lib lvs
                | None -> art_nid_canonical Lib
              in
              add_edge ~tag:bt [%string "%{ocaml_n} --> A_%{bt}"];
              add_edge ~tag:bt [%string "%{lib_n} -.->|link| A_%{bt}"])
      end);
  (* Summary follow-up edges (dashed) *)
  List.iter steps ~f:(fun s ->
      if String.is_suffix s.tag ~suffix:"_inspect" then begin
        let parent_tag =
          if String.is_suffix s.tag ~suffix:"_stub_inspect" then
            String.chop_suffix_exn s.tag ~suffix:"_stub_inspect"
          else
            String.chop_suffix_exn s.tag ~suffix:"_inspect"
        in
        if has_step parent_tag then
          add_edge ~tag:s.tag [%string "A_%{parent_tag} -.-> A_%{s.tag}"]
      end);
  add "";
  (* ── Styling ── *)
  add "    classDef artifact fill:#fff3e0,stroke:#ff9800,stroke-width:2px";
  add "    classDef store fill:#e8eaf6,stroke:#3f51b5,stroke-width:1.5px";
  add "    classDef st_done fill:#c8e6c9,stroke:#4caf50,stroke-width:3px";
  add "    classDef st_done_ctx fill:#e8f5e9,stroke:#a5d6a7,stroke-width:1.5px";
  add "    classDef st_expected_fail fill:#fff9c4,stroke:#f9a825,stroke-width:2px";
  add "    classDef st_failed fill:#ffcdd2,stroke:#c62828,stroke-width:2px";
  add "    classDef st_skipped fill:#f5f5f5,stroke:#9e9e9e,stroke-dasharray:5";
  add "    classDef st_nospec fill:#fafafa,stroke:#bdbdbd,stroke-dasharray:5";
  (* Artifact class for all variant nodes (nids already resolved in kind_variants) *)
  let all_art_nids =
    List.concat_map kind_data ~f:(fun (_, (variants, _, _, _)) ->
        match variants with [] -> [] | _ -> List.map variants ~f:snd)
  in
  if not (List.is_empty all_art_nids) then
    add [%string "    class %{String.concat all_art_nids ~sep:\",\"} artifact"];
  List.iter stores ~f:(fun pm ->
      add [%string "    class %{pm}_store store"]);
  (* Status classes for action nodes *)
  (match status with
   | None -> ()
   | Some tbl ->
       List.iter steps ~f:(fun s ->
           let nid = "A_" ^ s.tag in
           let cls = match Hashtbl.find tbl s.tag with
             | Some Canary.Done -> "st_done"
             | Some Canary.Done_fail -> "st_expected_fail"
             | Some Canary.Failed -> "st_failed"
             | Some Canary.Skipped -> "st_skipped"
             | Some Canary.Not_in_spec | None -> "st_nospec"
           in
           add [%string "    class %{nid} %{cls}"]));
  (* linkStyle coloring based on downstream step status *)
  let edge_styles =
    List.map (List.rev !edge_tags) ~f:(fun (idx, tag) ->
        let is_done = match status with
          | None -> false
          | Some tbl -> (match Hashtbl.find tbl tag with
              | Some Canary.Done | Some Canary.Done_fail -> true | _ -> false)
        in
        let style = if is_done then
            "stroke:#4caf50,stroke-width:3px"
          else
            "stroke:#bdbdbd,stroke-width:1px,stroke-dasharray:5"
        in
        [%string "    linkStyle %{Int.to_string idx} %{style}"])
  in
  List.iter edge_styles ~f:add;
  Buffer.contents buf

let mermaid_view
    ?(status : (string, node_status) Hashtbl.t option)
    ?(rules : rule list option)
    ?(step_ids : (string, int) Hashtbl.t option)
    ?(steps_by_rule_tag : (string, string list) Hashtbl.t option)
    ?(summary_rules : (rule * string) list option)
    ?(artifact_names : (artifact_kind -> string option) = fun _ -> None)
    ?(variant_infos : (string * string * string list) list = [])
    ?(has_scan = false)
    ~view
    (steps : action_step list)
    : string =
  let title = "view: " ^ view_name view in
  let fp = Some (focal_tag_pred view) in
  let sids = Option.value step_ids ~default:(Hashtbl.create (module String)) in
  let summary_tags_by_canonical =
    match summary_rules with
    | None -> None
    | Some srules ->
        let norm_suffix tail =
          if String.is_suffix tail ~suffix:"_stub_inspect" then "_stub_inspect"
          else "_inspect"
        in
        let tbl = Hashtbl.create (module String) in
        List.iter srules ~f:(fun (rule, suffix) ->
            let canonical = string_of_rule rule ^ suffix in
            let rule_base = string_of_rule rule in
            let concretes = List.filter_map steps ~f:(fun s ->
                if Poly.equal s.rule rule
                && String.is_suffix s.tag ~suffix:"_inspect" then
                  match String.chop_prefix s.tag ~prefix:rule_base with
                  | Some tail when String.equal (norm_suffix tail) suffix -> Some s.tag
                  | _ -> None
                else None)
            in
            Hashtbl.set tbl ~key:canonical ~data:concretes);
        Some tbl
  in
  (* Probe parameters (prefix, build_tag, fetch_tag) for a given probe kind. *)
  let probe_params kind =
    match kind with
    | Lib -> "probe_lib", "build_lib", "fetch_lib"
    | Binding lang ->
        let s = Canary_lang.string_of_lang lang in
        "probe_binding_" ^ s, "build_binding_" ^ s, "fetch_binding_" ^ s
    | App -> "probe_app", "build_app", "fetch_app"
    | _ -> "", "", ""
  in
  (* Which probe kinds to expand in this view.
     - Lib view       → only Probe Lib (lib variants are the focus)
     - Binding view   → only Probe (Binding lang) for the focal language
     - Probes view    → all probe kinds (probes are the entire subject)
     - Source / Pack  → none (probes are background context) *)
  let focal_probe_kinds : artifact_kind list option =
    match view with
    | `Lib      -> Some [ Lib ]
    | `Binding lang -> Some [ Binding lang ]
    | `Probes   -> None                     (* None = expand all *)
    | _         -> Some []                  (* expand none *)
  in
  let all_probe_expand =
    List.filter_map steps ~f:(fun s ->
        match s.rule with
        | Canary_basic.Probe k when not (String.is_suffix s.tag ~suffix:"_inspect") -> Some k
        | _ -> None)
    |> List.dedup_and_sort ~compare:Poly.compare
    |> (match focal_probe_kinds with
        | None       -> Fn.id
        | Some kinds -> List.filter ~f:(fun k -> List.mem kinds k ~equal:Poly.equal))
    |> List.filter_map ~f:(fun k ->
           let pp, bt, ft = probe_params k in
           if String.is_empty pp then None
           else _compute_probe_expand ~artifact_kind:k ~probe_prefix:pp
                  ~build_tag:bt ~fetch_tag:ft ~step_ids:sids steps)
  in
  match view with
  | `Binding lang ->
      (* Focused binding view: schema graph with the focal binding expanded per-variant.
         All other kinds render as overview-style pool nodes (no subgraphs). *)
      let s_lang = Canary_lang.string_of_lang lang in
      let expand =
        _compute_expand ~artifact_kind:(Binding lang)
          ~probe_prefix:("probe_binding_" ^ s_lang)
          ~build_tag:("build_binding_" ^ s_lang)
          ~fetch_tag:("fetch_binding_" ^ s_lang)
          ~artifact_names ~variant_infos ~label_kind:(s_lang ^ " binding")
          ~step_ids:sids steps
      in
      (match rules, step_ids, steps_by_rule_tag, summary_rules with
       | Some rules, Some sids2, Some sbrt, Some srules ->
           mermaid_of_action_rule_schema ?status ~has_scan:false
             ~summary_rules:srules ~step_ids:sids2 ~steps_by_rule_tag:sbrt
             ?summary_tags_by_canonical
             ?expand_artifact:expand ~expand_probe_kinds:all_probe_expand
             ~view_title:title ?focal_predicate:fp rules
       | _ ->
           mermaid_of_steps ?status ~title ~all_steps:steps
             ~filter:(view_predicate view) ())
  | `Lib ->
      (* Focused lib view: schema graph with lib artifact expanded per-variant. *)
      let expand =
        _compute_expand ~artifact_kind:Lib ~probe_prefix:"probe_lib"
          ~build_tag:"build_lib" ~fetch_tag:"fetch_lib"
          ~artifact_names ~variant_infos ~label_kind:"lib" ~step_ids:sids steps
      in
      (match rules, step_ids, steps_by_rule_tag, summary_rules with
       | Some rules, Some sids2, Some sbrt, Some srules ->
           mermaid_of_action_rule_schema ?status ~has_scan
             ~summary_rules:srules ~step_ids:sids2 ~steps_by_rule_tag:sbrt
             ?summary_tags_by_canonical
             ?expand_artifact:expand ~expand_probe_kinds:all_probe_expand
             ~view_title:title ?focal_predicate:fp rules
       | _ ->
           mermaid_of_steps ?status ~title ~all_steps:steps
             ~filter:(view_predicate view) ())
  | _ ->
      (* Source, Pack, Probes, Full: full schema graph, all probes expanded to concrete nodes.
         Full additionally chains configure through scan_source when present. *)
      let chain_scan = match view with `Full -> true | _ -> false in
      (match rules, step_ids, steps_by_rule_tag, summary_rules with
       | Some rules, Some sids2, Some sbrt, Some srules ->
           mermaid_of_action_rule_schema ?status ~has_scan ~chain_scan
             ~summary_rules:srules ~step_ids:sids2 ~steps_by_rule_tag:sbrt
             ?summary_tags_by_canonical
             ~expand_probe_kinds:all_probe_expand
             ~view_title:title ?focal_predicate:fp rules
       | _ ->
           mermaid_of_steps ?status ~title ~all_steps:steps
             ~filter:(view_predicate view) ())

let _list_dirs path =
  if not (Stdlib.Sys.file_exists path) then []
  else
    try
      Stdlib.Sys.readdir path
      |> Array.to_list
      |> List.filter ~f:(fun n ->
          let p = path ^ "/" ^ n in
          Stdlib.Sys.file_exists p && Stdlib.Sys.is_directory p)
    with _ -> []

let _read_file_lines path =
  try
    let ic = Stdlib.open_in path in
    let rec loop acc =
      match Stdlib.input_line ic with
      | l -> loop (l :: acc)
      | exception End_of_file -> Stdlib.close_in ic; List.rev acc
    in
    loop []
  with _ -> []

(* Coarse status counts from actions.log: each step emits a "done" or
   "failed" or "skipped" event line. We count distinct step tags. *)
let _counts_from_log ~variant_dir =
  let log = variant_dir ^ "/actions.log" in
  let lines = _read_file_lines log in
  let by_tag = Hashtbl.create (module String) in
  List.iter lines ~f:(fun line ->
      (* Format: "[YYYY-MM-DD HH:MM:SS.SSS] <tag><spaces><event>  ..." *)
      match String.lsplit2 line ~on:']' with
      | None -> ()
      | Some (_, rest) ->
          let rest = String.lstrip rest in
          (match String.split rest ~on:' ' with
           | tag :: rest_tokens ->
               let event = List.find rest_tokens ~f:(fun t ->
                   not (String.is_empty t)) in
               (match event with
                | Some "done" -> Hashtbl.set by_tag ~key:tag ~data:"done"
                | Some "failed" -> Hashtbl.set by_tag ~key:tag ~data:"failed"
                | Some "skipped" ->
                    (* Don't override done/failed *)
                    if not (Hashtbl.mem by_tag tag) then
                      Hashtbl.set by_tag ~key:tag ~data:"skipped"
                | _ -> ())
           | _ -> ()));
  let total = Hashtbl.length by_tag in
  let done_ = Hashtbl.count by_tag ~f:(String.equal "done") in
  let failed = Hashtbl.count by_tag ~f:(String.equal "failed") in
  let skipped = Hashtbl.count by_tag ~f:(String.equal "skipped") in
  (total, done_, failed, skipped)

let _format_mtime (t : float) =
  let tm = Unix.localtime t in
  Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d"
    (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday
    tm.tm_hour tm.tm_min tm.tm_sec

let _source_kind_of_run_info ~variant_dir =
  let p = variant_dir ^ "/run_info.json" in
  if not (Stdlib.Sys.file_exists p) then ""
  else
    let lines = _read_file_lines p in
    (* New multi-variant format: find source inside first "variants" object.
       Old flat format: find top-level "source" key.
       Both cases: first line matching `"source": "..."` wins. *)
    List.find_map lines ~f:(fun l ->
        let l = String.strip l in
        match String.chop_prefix l ~prefix:{|"source": |} with
        | Some s ->
            Some (String.strip ~drop:(fun c ->
                Char.equal c '"' || Char.equal c ','
                || Char.equal c ' ') s)
        | None -> None)
    |> Option.value ~default:""

let _counts_from_run_state ~run_dir =
  let p = run_dir ^ "/run_state.json" in
  if not (Stdlib.Sys.file_exists p) then _counts_from_log ~variant_dir:run_dir
  else
    try
      let j = Yojson.Basic.from_file p in
      let open Yojson.Basic.Util in
      let steps = j |> member "steps" |> to_list in
      let counts = List.fold steps ~init:(0, 0, 0, 0)
          ~f:(fun (t, d, f, s) sj ->
              let st = sj |> member "status" |> to_string in
              match st with
              | "done"    -> (t+1, d+1, f,   s  )
              | "failed"  -> (t+1, d,   f+1, s  )
              | "skipped" -> (t+1, d,   f,   s+1)
              | _         -> (t,   d,   f,   s  ))
      in
      counts
    with _ -> _counts_from_log ~variant_dir:run_dir

let scan_index_entries ~projects_root : Canary_html.index_entry list =
  if not (Stdlib.Sys.file_exists projects_root) then []
  else
    let make_entry ~project ~proj_dir =
      let run_dir = proj_dir ^ "/-run" in
      let html_path = run_dir ^ "/result.html" in
      if not (Stdlib.Sys.file_exists html_path) then None
      else
        let mtime = (Unix.stat html_path).st_mtime in
        let (total, done_, failed, skipped) = _counts_from_run_state ~run_dir in
        let src = _source_kind_of_run_info ~variant_dir:run_dir in
        Some Canary_html.{
          project; variant = "";
          run_at = _format_mtime mtime;
          href = project ^ "/-run/result.html";
          total_steps = total;
          done_steps = done_;
          failed_steps = failed;
          skipped_steps = skipped;
          source_kind = src;
        }
    in
    let projects = _list_dirs projects_root in
    List.filter_map projects ~f:(fun project ->
        make_entry ~project ~proj_dir:(projects_root ^ "/" ^ project))

(* Read run_info.json and return (variant_id, version, actions) triples.
   `actions` is the list of step tags that ran in that variant. *)
let _variant_infos_of_run_info ~run_dir : (string * string * string list) list =
  let p = run_dir ^ "/run_info.json" in
  if not (Stdlib.Sys.file_exists p) then []
  else
    try
      let j = Yojson.Basic.from_file p in
      let open Yojson.Basic.Util in
      let str_list v = v |> to_list |> List.filter_map ~f:to_string_option in
      (match j |> member "variants" with
       | `List vs ->
           List.filter_map vs ~f:(fun v ->
               let id  = v |> member "id"      |> to_string_option in
               let ver = v |> member "version"  |> to_string_option in
               let acts = v |> member "actions" |> str_list in
               match (id, ver) with
               | (Some i, Some v) -> Some (i, v, acts)
               | _ -> None)
       | _ ->
           (* Single-variant flat format: top-level "version" field *)
           let acts = j |> member "actions" |> str_list in
           (match j |> member "version" |> to_string_option with
            | Some v -> [ ("", v, acts) ]
            | _ -> []))
    with _ -> []

(* ── Output generation ──
   Writes diagrams/all.mmd, per-view diagrams, result.html, and refreshes
   index.html. Shared by run_project (single-variant) and run_project_multi. *)

let write_project_output ~dir ~project_name ~variant ~steps
    ~(run_status : (string, step_status) Hashtbl.t)
    ~(artifact_names : artifact_kind -> string option)
    ~root logger =
  let node_status = result_status_of_run steps run_status in
  let langs =
    List.filter_map steps ~f:(fun s ->
        match s.rule with
        | Build_binding lang | Fetch (Binding lang)
        | Publish (Binding lang) | Probe (Binding lang) -> Some lang
        | _ -> None)
    |> List.dedup_and_sort ~compare:Poly.compare
    |> fun ls -> if List.is_empty ls then Canary_lang.[ OCaml ] else ls
  in
  let has_scan = List.exists steps ~f:(fun s -> String.equal s.tag "scan_source") in
  let summary_rules =
    let canonical_parent_tag rule = string_of_rule rule in
    List.filter_map steps ~f:(fun s ->
        if String.is_suffix s.tag ~suffix:"_inspect" then
          let parent = canonical_parent_tag s.rule in
          if String.is_prefix s.tag ~prefix:parent then
            let suffix = String.chop_prefix_exn s.tag ~prefix:parent in
            let normalised =
              if String.is_suffix suffix ~suffix:"_stub_inspect"
              then "_stub_inspect"
              else "_inspect"
            in
            Some (s.rule, normalised)
          else None
        else None)
    |> List.dedup_and_sort
         ~compare:(fun (r1, s1) (r2, s2) ->
           match Poly.compare r1 r2 with
           | 0 -> String.compare s1 s2
           | n -> n)
  in
  let step_ids = step_id_table steps in
  (* steps_by_rule_tag: maps rule name → concrete step tags for [N] label embedding.
     Two variants: overview includes scan_source in the source artifact label;
     focused views exclude it (scan gets its own standalone node). *)
  let mk_steps_by_rule_tag ~include_scan =
    let tbl = Hashtbl.create (module String) in
    List.iter steps ~f:(fun s ->
        let skip =
          String.is_suffix s.tag ~suffix:"_inspect"
          || (String.equal s.tag "scan_source" && not include_scan)
        in
        if not skip then
          let key = string_of_rule s.rule in
          Hashtbl.update tbl key ~f:(function
            | None -> [ s.tag ]
            | Some xs -> s.tag :: xs));
    tbl
  in
  let steps_by_rule_tag_overview = mk_steps_by_rule_tag ~include_scan:true in
  let steps_by_rule_tag = mk_steps_by_rule_tag ~include_scan:false in
  (* All run metadata (diagrams, HTML, logs, run_info, run_state) go into -run/
     so step output directories remain at the project root level. *)
  let run_dir = [%string "%{dir}/-run"] in
  ensure_dir run_dir;
  (* Overview diagram → -run/diagrams/all.mmd *)
  let view_dir = [%string "%{run_dir}/diagrams"] in
  ensure_dir view_dir;
  (* Maps canonical summary tag → all concrete step tags for that summary kind.
     E.g. "probe_lib_inspect" → ["probe_lib_inspect";"probe_lib_staged_inspect";"probe_lib_apt_inspect"]
     Used by the overview to show all concrete IDs in one collapsed summary node. *)
  let summary_tags_by_canonical =
    (* Normalize a tag suffix to "_stub_inspect" or "_inspect".
       Required because String.is_suffix ~suffix:"_inspect" also matches
       "_stub_inspect", which would double-count step 11 in both buckets. *)
    let norm_suffix tail =
      if String.is_suffix tail ~suffix:"_stub_inspect" then "_stub_inspect"
      else "_inspect"
    in
    let tbl = Hashtbl.create (module String) in
    List.iter summary_rules ~f:(fun (rule, suffix) ->
        let canonical = string_of_rule rule ^ suffix in
        let rule_base = string_of_rule rule in
        let concretes = List.filter_map steps ~f:(fun s ->
            if Poly.equal s.rule rule
            && String.is_suffix s.tag ~suffix:"_inspect" then
              match String.chop_prefix s.tag ~prefix:rule_base with
              | Some tail when String.equal (norm_suffix tail) suffix -> Some s.tag
              | _ -> None
            else None)
        in
        Hashtbl.set tbl ~key:canonical ~data:concretes);
    tbl
  in
  (* Overview: scan merged into source artifact label; no standalone scan node *)
  let overview_mmd =
    mermaid_of_action_rule_schema ~status:node_status ~has_scan:false
      ~summary_rules ~step_ids ~steps_by_rule_tag:steps_by_rule_tag_overview
      ~summary_tags_by_canonical
      (store_rules ~langs)
  in
  let all_mmd_path = [%string "%{view_dir}/all.mmd"] in
  let oc = Stdlib.open_out all_mmd_path in
  Stdlib.output_string oc overview_mmd;
  Stdlib.close_out oc;
  logger.log ~tag:"*" ~event:"diagram" ~detail:(Some all_mmd_path);
  (* Full diagram: all probes expanded as individual nodes, no focal distinction *)
  let variant_infos = _variant_infos_of_run_info ~run_dir in
  let full_mmd =
    mermaid_full ~status:node_status ~step_ids ~has_scan ~summary_rules
      ~variant_infos ~artifact_names steps
  in
  let full_mmd_path = [%string "%{view_dir}/full.mmd"] in
  let oc = Stdlib.open_out full_mmd_path in
  Stdlib.output_string oc full_mmd;
  Stdlib.close_out oc;
  logger.log ~tag:"*" ~event:"diagram" ~detail:(Some full_mmd_path);
  (* Per-view diagrams *)
  let views : view list =
    [ `Source; `Lib; `Probes ]
    @ List.map langs ~f:(fun l -> `Binding l)
  in
  let emitted_views = ref [] in
  List.iter views ~f:(fun v ->
      let filtered = List.filter steps ~f:(view_predicate v) in
      if not (List.is_empty filtered) then begin
        let path = [%string "%{view_dir}/%{view_name v}.mmd"] in
        let sbrt = match v with
          | `Binding _ -> steps_by_rule_tag_overview
          | _ -> steps_by_rule_tag
        in
        let mmd = mermaid_view ~status:node_status ~view:v
            ~rules:(store_rules ~langs) ~step_ids ~steps_by_rule_tag:sbrt
            ~summary_rules ~has_scan ~artifact_names ~variant_infos steps in
        let oc = Stdlib.open_out path in
        Stdlib.output_string oc mmd;
        Stdlib.close_out oc;
        emitted_views := (v, mmd) :: !emitted_views;
        logger.log ~tag:"*" ~event:"view"
          ~detail:(Some [%string "%{view_name v} (%{Int.to_string (List.length filtered)} steps)"])
      end);
  let html_path = [%string "%{run_dir}/result.html"] in
  let html_views =
    Canary_html.{ name = "overview"; title = "Overview"; mmd = overview_mmd }
    :: Canary_html.{ name = "full"; title = "Full"; mmd = full_mmd }
    :: List.rev_map !emitted_views ~f:(fun (v, mmd) ->
        let n = view_name v in
        let title = match v with
          | `Source -> "Source"
          | `Lib -> "Lib"
          | `Pack -> "Pack"
          | `Probes -> "Probes"
          | `Full -> "Full"
          | `Binding lang ->
              "Binding (" ^ Canary_lang.display_of_lang lang ^ ")"
        in
        Canary_html.{ name = n; title; mmd })
  in
  let html_steps =
    List.map steps ~f:(fun s ->
        let exp_str = match s.expectation with
          | Expect_success -> "Expect_success"
          | Expect_failure _ -> "Expect_failure"
          | Expect_compat_failure _ -> "Expect_compat_failure"
        in
        let status_str = match Hashtbl.find node_status s.tag with
          | Some Canary.Done -> "done"
          | Some Canary.Done_fail -> "expected_fail"
          | Some Canary.Failed -> "failed"
          | Some Canary.Skipped -> "skipped"
          | Some Canary.Not_in_spec | None -> "not_in_spec"
        in
        (* output_rel: path from -run/ to the step dir one level up. *)
        let step_dir = Canary_basic.step_dir_of_tag s.output_tag in
        Canary_html.{
          id = Hashtbl.find step_ids s.tag;
          tag = s.tag;
          rule = string_of_rule s.rule;
          output_rel = "../" ^ step_dir;
          variant_key = s.variant_id;
          expectation = exp_str;
          status = status_str;
        })
  in
  let run_at =
    let t = Unix.gettimeofday () in
    let tm = Unix.localtime t in
    Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d"
      (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday
      tm.tm_hour tm.tm_min tm.tm_sec
  in
  let html =
    Canary_html.render
      ~project:project_name ~variant
      ~run_at ~index_rel:"../../index.html"
      ~views:html_views
      ~default_view:"overview"
      ~steps:html_steps
  in
  let oc = Stdlib.open_out html_path in
  Stdlib.output_string oc html;
  Stdlib.close_out oc;
  logger.log ~tag:"*" ~event:"html" ~detail:(Some html_path);
  let projects_root = [%string "%{root}/canary/projects"] in
  let index_path = projects_root ^ "/index.html" in
  let entries = scan_index_entries ~projects_root in
  let index_html = Canary_html.render_index ~entries ~generated_at:run_at in
  let oc = Stdlib.open_out index_path in
  Stdlib.output_string oc index_html;
  Stdlib.close_out oc;
  logger.log ~tag:"*" ~event:"index" ~detail:(Some index_path);
  (* ── Diagram invariant check ────────────────────────────────────────────
     Two properties are verified for every .mmd written:

     1. Coverage: the union of all [N] IDs in node labels equals the full step set.
     2. Connectivity: for every step S that depends on step D, the diagram must
        contain an edge from a node containing D's [N] to a node containing S's [N].
        This guarantees that zooming (merging/expanding nodes) preserves the
        dependency topology — if two steps are connected in the full view, they
        remain connected (through their merged representative nodes) in every
        other view. ── *)
  let re_nid = Str.regexp {|^[ \t]*\([A-Za-z_][A-Za-z_0-9]*\)|} in
  let re_edge = Str.regexp {|^[ \t]*\([A-Za-z_][A-Za-z_0-9]*\)[ \t]*\(-->\|-\.->\)|} in
  let re_id = Str.regexp {|\[\([0-9]+\)\]|} in
  let ground_ids =
    Hashtbl.fold step_ids ~init:(Set.empty (module Int))
      ~f:(fun ~key:_ ~data:n acc -> Set.add acc n)
  in
  let string_of_int_set s =
    Set.to_list s |> List.map ~f:Int.to_string |> String.concat ~sep:"," in
  let parse_mmd path =
    try
      let ic = Stdlib.open_in path in
      let content = Stdlib.really_input_string ic (Stdlib.in_channel_length ic) in
      Stdlib.close_in ic;
      let node_ids = Hashtbl.create (module String) in
      let adj = Hashtbl.create (module String) in
      let add_edge src dst =
        Hashtbl.update adj src ~f:(function
            | None -> [dst] | Some xs -> if List.mem xs dst ~equal:String.equal then xs else dst :: xs)
      in
      let lines = String.split_lines content in
      List.iter lines ~f:(fun line ->
          (* Node definitions: extract nid and [N] IDs from label.
             A node line has shape: NID@{...} or NID(["label"]) or NID{{"label"}} *)
          if Str.string_match re_nid line 0 then
            let nid = Str.matched_group 1 line in
            let after_nid = String.sub line ~pos:(Str.match_end ())
                ~len:(String.length line - Str.match_end ()) in
            let after_nid = String.lstrip after_nid in
            let is_node = String.is_prefix after_nid ~prefix:"@"
                       || String.is_prefix after_nid ~prefix:"(["
                       || String.is_prefix after_nid ~prefix:"{{\""
                       || String.is_prefix after_nid ~prefix:"["
            in
            if is_node then begin
              let ids = ref [] in
              let pos = ref 0 in
              (try
                 while !pos < String.length line do
                   let _ = Str.search_forward re_id line !pos in
                   let n = Int.of_string (Str.matched_group 1 line) in
                   ids := n :: !ids;
                   pos := Str.match_end ()
                 done
               with _ -> ());
              (match List.rev !ids with [] -> () | ids' -> Hashtbl.set node_ids ~key:nid ~data:ids')
            end
          (* Edge definitions: extract all chained edges (A --> B --> C) *)
          else if Str.string_match re_edge line 0 then (
            let rec parse_chain pos prev_src =
              (* Find next arrow at pos *)
              try
                let _ = Str.search_forward re_edge line pos in
                let arrow_src = Str.matched_group 1 line in
                let arrow_match_end = Str.match_end () in
                let src = match prev_src with
                  | Some s -> s
                  | None -> arrow_src
                in
                (* Extract target after arrow *)
                let rest = String.sub line ~pos:arrow_match_end
                    ~len:(String.length line - arrow_match_end) in
                let rest = String.lstrip rest in
                (* Skip optional |label| *)
                let rest =
                  if String.is_prefix rest ~prefix:"|" then
                    match String.index rest '|' with
                    | Some i when i + 1 < String.length rest ->
                        String.sub rest ~pos:(i + 1)
                          ~len:(String.length rest - i - 1)
                        |> String.lstrip
                    | _ -> rest
                  else rest
                in
                (match String.split rest ~on:' ' with
                 | dst :: _ when not (String.is_empty dst) ->
                     add_edge src dst;
                     (* Continue with dst as next src *)
                     parse_chain arrow_match_end (Some dst)
                 | _ -> ())
              with _ -> ()
            in
            parse_chain 0 None
          )
      );
      Some (node_ids, adj)
    with _ -> None
  in
  (* Build ground-truth dependency graph: step_id → [dep_step_ids] *)
  let step_deps = Hashtbl.create (module Int) in
  List.iter steps ~f:(fun s ->
      match Hashtbl.find step_ids s.tag with
      | None -> ()
      | Some n ->
          let deps = List.filter_map s.deps ~f:(fun d -> Hashtbl.find step_ids d) in
          Hashtbl.set step_deps ~key:n ~data:deps);
  let check_one_mmd fn =
    let path = Stdlib.Filename.concat view_dir fn in
    match parse_mmd path with
    | None ->
        logger.log ~tag:"!" ~event:"invariant"
          ~detail:(Some (fn ^ ": could not parse"));
        false
    | Some (node_ids, adj) ->
        (* Coverage *)
        let have = Hashtbl.fold node_ids ~init:(Set.empty (module Int))
            ~f:(fun ~key:_ ~data:ids acc ->
                List.fold ids ~init:acc ~f:(fun acc n -> Set.add acc n))
        in
        let missing = Set.diff ground_ids have in
        let extra = Set.diff have ground_ids in
        let cov_ok = Set.is_empty missing && Set.is_empty extra in
        if not cov_ok then begin
          if not (Set.is_empty missing) then
            logger.log ~tag:"!" ~event:"invariant"
              ~detail:(Some (fn ^ ": missing [" ^ string_of_int_set missing ^ "]"));
          if not (Set.is_empty extra) then
            logger.log ~tag:"!" ~event:"invariant"
              ~detail:(Some (fn ^ ": extra [" ^ string_of_int_set extra ^ "]"))
        end;
        (* Connectivity: for each (step_id, dep_id) pair, check edge exists *)
        let node_of_id = Hashtbl.create (module Int) in
        Hashtbl.iteri node_ids ~f:(fun ~key:nid ~data:ids ->
            List.iter ids ~f:(fun id -> Hashtbl.set node_of_id ~key:id ~data:nid));
        (* Compute reachability via BFS on the edge graph *)
        let reachable = Hashtbl.create (module String) in
        let bfs start =
          match Hashtbl.find reachable start with
          | Some _ -> ()
          | None ->
              let visited = Hash_set.create (module String) in
              let queue = ref [start] in
              Hash_set.add visited start;
              let targets = ref [] in
              while not (List.is_empty !queue) do
                (match !queue with
                 | node :: rest ->
                     queue := rest;
                     (match Hashtbl.find adj node with
                      | Some dsts ->
                          List.iter dsts ~f:(fun dst ->
                              if not (Hash_set.mem visited dst) then begin
                                Hash_set.add visited dst;
                                queue := dst :: !queue;
                                targets := dst :: !targets
                              end)
                      | None -> ())
                 | [] -> ())
              done;
              Hashtbl.set reachable ~key:start ~data:(Hash_set.to_list visited)
        in
        let path_exists src dst =
          bfs src;
          match Hashtbl.find reachable src with
          | Some nodes -> List.mem nodes dst ~equal:String.equal
          | None -> false
        in
        let edge_exists = path_exists in
        let conn_errors = ref [] in
        Hashtbl.iteri step_deps ~f:(fun ~key:nid ~data:dep_ids ->
            match Hashtbl.find node_of_id nid with
            | None ->
                conn_errors :=
                  [%string "  step [%{Int.to_string nid}]: node not found"] :: !conn_errors
            | Some step_node ->
                List.iter dep_ids ~f:(fun dep_id ->
                    match Hashtbl.find node_of_id dep_id with
                    | None ->
                        conn_errors :=
                          [%string "  dep [%{Int.to_string dep_id}]: node not found"] :: !conn_errors
                    | Some dep_node ->
                        if not (edge_exists dep_node step_node) then
                          conn_errors :=
                            [%string "  [%{Int.to_string dep_id}]→[%{Int.to_string nid}]: no edge %{dep_node}→%{step_node}"]
                            :: !conn_errors));
        let conn_ok = List.is_empty !conn_errors in
        if not conn_ok then
          logger.log ~tag:"!" ~event:"invariant"
            ~detail:(Some (fn ^ ": connectivity errors:\n"
                          ^ String.concat ~sep:"\n" (List.rev !conn_errors)));
        let ok = cov_ok && conn_ok in
        if ok then
          logger.log ~tag:"*" ~event:"invariant"
            ~detail:(Some (fn ^ ": OK (" ^ Int.to_string (Hashtbl.length node_ids)
                           ^ " nodes, " ^ Int.to_string (Set.length have) ^ " IDs)"));
        ok
  in
  let files = try Stdlib.Sys.readdir view_dir |> Array.to_list with _ -> [] in
  let mmd_files = List.filter files ~f:(fun f -> String.is_suffix f ~suffix:".mmd") in
  let all_ok = List.for_all mmd_files ~f:check_one_mmd in
  if all_ok then
    logger.log ~tag:"*" ~event:"invariant" ~detail:(Some "ALL OK")
  else
    logger.log ~tag:"!" ~event:"invariant" ~detail:(Some "SOME FAILED");
  (* Copy web-viewable output to docs/ for GitHub Pages. *)
  let docs_projects = "docs/canary/projects" in
  let docs_dir = [%string "%{docs_projects}/%{project_name}"] in
  ignore (Stdlib.Sys.command [%string "mkdir -p \"%{docs_dir}\""]);
  ignore (Stdlib.Sys.command [%string "cp -r \"%{dir}\"/* \"%{docs_dir}\"/"]);
  ignore (Stdlib.Sys.command [%string "find \"%{docs_dir}\" -name '*.ok' -delete"]);
  ignore (Stdlib.Sys.command [%string "find \"%{docs_dir}\" -name 'pack-repo' -type d -prune -exec rm -rf {} +"]);
  ignore (Stdlib.Sys.command [%string "find \"%{docs_dir}\" -name '*_example*' -type f -delete"]);
  let entries = scan_index_entries ~projects_root:docs_projects in
  let docs_index_html = Canary_html.render_index ~entries ~generated_at:run_at in
  let docs_index_path = docs_projects ^ "/index.html" in
  let oc = Stdlib.open_out docs_index_path in
  Stdlib.output_string oc docs_index_html;
  Stdlib.close_out oc

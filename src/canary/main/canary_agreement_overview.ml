(** §2 of the overview page, the agreement overview: one row per agreement
    and firing pattern, over §1.2's frames — what it reads (▣), where its
    rule ran (R), where it is checked (D) and its own column (◆) — with how
    often recorded runs decided it and whose defect the rest are; then the
    agreements grouped by where they sit on the chain. [decided] and
    [blame] count §1.2's cells ({!Canary_matrix.row.checks}), so this
    section alone depends on recorded runs. *)

open Base
module M = Canary_matrix
module E = Canary_overview_exhibits

(* ── where the agreements sit ── *)

type sitting_member = { sm_slug : string; sm_checked : bool; sm_decided : bool }

(** The agreements whose claim sites sit alike — same reach, same layers —
    with whether each is checked (the registry has an evaluator) and
    decided (a recorded run reached holds or violated). *)
type sitting_group = {
  sg_reach : Canary_topology.reach;
  sg_layers : Canary_topology.layer list;
  sg_members : sitting_member list;
}

(** The agreements some recorded run decided — held or violated in some
    cell of §1.2, wherever the check sits. *)
let decided_slugs (m : M.t) : string list =
  List.concat_map m.M.rows ~f:(fun r ->
      List.concat_map r.M.checks ~f:(fun (_, cells) ->
          List.filter_map cells ~f:(fun (slug, c) ->
              match c.M.chk_outcome with "holds" | "violated" -> Some slug | _ -> None)))
  |> List.dedup_and_sort ~compare:String.compare

(** Every agreement the diagram places, registered and candidate, grouped
    by where its claim site sits ({!Canary_topology.sitting_of}). *)
let sitting_groups (m : M.t) : sitting_group list =
  let module T = Canary_topology in
  let decided = decided_slugs m in
  let reach_rank = function
    | T.Own_side T.S_sys -> 0
    | T.Own_side T.S_lang -> 1
    | T.Across_sides -> 2
    | T.End_to_end -> 3
  in
  let key (s : T.sitting) = (reach_rank s.T.st_reach, List.map s.T.st_layers ~f:T.layer_rank) in
  let placed =
    List.map T.claim_sites ~f:(fun cs ->
        ( T.sitting_of_site cs,
          { sm_slug = cs.T.cs_claim;
            sm_checked = T.implemented cs;
            sm_decided = List.mem decided cs.T.cs_claim ~equal:String.equal } ))
  in
  List.map placed ~f:(fun (s, _) -> key s)
  |> List.dedup_and_sort ~compare:Poly.compare
  |> List.filter_map ~f:(fun k ->
         match List.filter placed ~f:(fun (s, _) -> Poly.equal (key s) k) with
         | [] -> None
         | (s, _) :: _ as group ->
             Some
               { sg_reach = s.T.st_reach;
                 sg_layers = s.T.st_layers;
                 sg_members = List.map group ~f:snd })

(** An agreement's mark in the grouping: decided in a run, checked but
    not yet decided in any, or named only. *)
let sitting_mark (sm : sitting_member) : string =
  if sm.sm_decided then "✓" else if sm.sm_checked then "·" else "?"

(** The grouping, for the terminal. *)
let pp_sittings (m : M.t) : string =
  let module T = Canary_topology in
  let groups = sitting_groups m in
  let line (g : sitting_group) =
    Printf.sprintf "  %-18s %-24s %2d %3d %3d   %s" (T.string_of_reach g.sg_reach)
      (T.string_of_layers g.sg_layers) (List.length g.sg_members)
      (List.count g.sg_members ~f:(fun sm -> sm.sm_checked))
      (List.count g.sg_members ~f:(fun sm -> sm.sm_decided))
      (String.concat ~sep:" "
         (List.map g.sg_members ~f:(fun sm ->
              Canary_agreement_common.short_code_of_slug sm.sm_slug ^ sitting_mark sm)))
  in
  String.concat ~sep:"\n"
    ([ "where the agreements sit on the chain — placed / checked / decided \
        (✓ decided in a run · checked, never decided · ? named only)";
       Printf.sprintf "  %-18s %-24s %2s %3s %3s   %s" "reaches" "layers" "pl" "chk" "dec"
         "agreements" ]
    @ List.map groups ~f:line)

(* ── the table ── *)

(** §2 as HTML: the verdict line, the legend, the kind glossary, the table
    and the grouping. *)
let render (m : M.t) : string =
  (* escapes the three markup characters, as this table always has *)
  let esc s =
    s
    |> String.substr_replace_all ~pattern:"&" ~with_:"&amp;"
    |> String.substr_replace_all ~pattern:"<" ~with_:"&lt;"
    |> String.substr_replace_all ~pattern:">" ~with_:"&gt;"
  in
  (* one cell per chain, the cells §1.2's rows are drawn from *)
  let cells_of slug =
    List.concat_map m.M.rows ~f:(fun (rr : M.row) ->
        List.filter_map rr.M.checks ~f:(fun (_, cells) ->
            List.Assoc.find cells slug ~equal:String.equal))
  in
  let tally slug =
    let cells = cells_of slug in
    let count o = List.count cells ~f:(fun c -> String.equal c.M.chk_outcome o) in
    match (count "holds", count "violated") with
    | 0, 0 -> "<span class=\"kq\">not decided in any row</span>"
    | h, 0 -> Printf.sprintf "%d ✓" h
    | 0, b -> Printf.sprintf "%d ✗" b
    | h, b -> Printf.sprintf "%d ✓ · %d ✗" h b
  in
  (* what those cells blame; blank where every cell is a verdict *)
  let blame_tally slug =
    let counts : (string, int) Hashtbl.t = Hashtbl.create (module String) in
    List.iter (cells_of slug) ~f:(fun c ->
        Option.iter c.M.chk_blame ~f:(fun b ->
            Hashtbl.update counts b ~f:(function None -> 1 | Some n -> n + 1)));
    Hashtbl.to_alist counts
    |> List.sort ~compare:(fun (_, a) (_, b) -> Int.compare b a)
    |> List.map ~f:(fun (b, n) ->
           Printf.sprintf "<span title=\"%s\">%d %s</span>" (esc
             (Option.value
                (List.Assoc.find M.blame_gloss b ~equal:String.equal)
                ~default:""))
             n (esc b))
    |> String.concat ~sep:" · "
  in
  let sittings_html =
    let module T = Canary_topology in
    let chip (sm : sitting_member) =
      Printf.sprintf "<code title=\"%s\">%s</code>%s" (esc sm.sm_slug)
        (esc (Canary_agreement_common.short_code_of_slug sm.sm_slug))
        (sitting_mark sm)
    in
    "<h3 id=\"sittings\">2.1 Where they sit on the chain</h3>"
    ^ "<p class=\"kq\">Every agreement the diagram places — registered and \
       candidate — grouped by where its claim site sits. <b>checked</b>: \
       the registry has an evaluator for it. <b>decided</b>: a recorded \
       run reached holds or violated. After each code: ✓ decided in a \
       run, · checked but never decided, ? named only.</p>"
    ^ E.table ~cls:"keytbl sittings" "tab-sittings"
    ^ "<thead><tr><th>reaches</th>\
       <th>layers</th><th>placed</th><th>checked</th><th>decided</th>\
       <th>agreements</th></tr></thead><tbody>"
    ^ String.concat ~sep:""
        (List.map (sitting_groups m) ~f:(fun g ->
             Printf.sprintf
               "<tr><td>%s</td><td>%s</td><td class=\"n\">%d</td><td \
                class=\"n\">%d</td><td class=\"n\">%d</td><td>%s</td></tr>"
               (esc (T.string_of_reach g.sg_reach))
               (esc (T.string_of_layers g.sg_layers))
               (List.length g.sg_members)
               (List.count g.sg_members ~f:(fun sm -> sm.sm_checked))
               (List.count g.sg_members ~f:(fun sm -> sm.sm_decided))
               (String.concat ~sep:" " (List.map g.sg_members ~f:chip))))
    ^ "</tbody></table>"
  in
  let recovery_grid =
    let module CR = Canary_agreement in
    let module Fr = Canary_frames in
    let rows = CR.overview_rows () in
    (* the same header as §1.2: its frames, by side, then frame, then
       column, with §1.2's layer classes *)
    let frame_head =
      let layer n =
        Option.value_map (Canary_topology.node_by_id n) ~default:"art" ~f:(fun nd ->
            match nd.Canary_topology.nd_layer with
            | Canary_topology.L_pm -> "pm"
            | Canary_topology.L_package -> "pkg"
            | Canary_topology.L_artifact -> "art"
            | Canary_topology.L_program -> "prog")
      in
      let layer_of_edge id =
        Option.value_map
          (List.find Canary_topology.edges ~f:(fun e -> String.equal e.Canary_topology.eg_id id))
          ~default:"art" ~f:(fun e -> layer e.Canary_topology.eg_to)
      in
      let sides =
        List.fold Fr.frames ~init:[] ~f:(fun acc fr ->
            let n = List.length fr.Fr.fr_columns in
            match acc with
            | (s, k) :: rest when Poly.equal s fr.Fr.fr_side -> (s, k + n) :: rest
            | _ -> (fr.Fr.fr_side, n) :: acc)
        |> List.rev
      in
      ( String.concat
          (List.map sides ~f:(fun (s, n) ->
               Printf.sprintf "<th class=\"rt-side\" colspan=\"%d\">%s</th>" n
                 (esc (Fr.label_of_side s)))),
        String.concat
          (List.map Fr.frames ~f:(fun fr ->
               Printf.sprintf "<th class=\"rt-fr\" colspan=\"%d\">%s</th>"
                 (List.length fr.Fr.fr_columns) (esc fr.Fr.fr_label))),
        String.concat
          (List.concat_map Fr.frames ~f:(fun fr ->
               List.map fr.Fr.fr_columns ~f:(function
                 | Fr.Node n ->
                     Printf.sprintf "<th class=\"rt-%s\" title=\"%s\">%s</th>" (layer n) (esc n)
                       (esc
                          (Option.value_map (Canary_topology.node_by_id n) ~default:n
                             ~f:(fun nd -> nd.Canary_topology.nd_label)))
                 | Fr.Piece { edges; label } ->
                     Printf.sprintf "<th class=\"rt-hp rt-u-%s\" title=\"%s\">%s</th>"
                       (layer_of_edge (List.hd_exn edges))
                       (esc (String.concat ~sep:", " edges)) (esc label)
                 | Fr.Check { slug; code; site; stage } ->
                     Printf.sprintf "<th class=\"rt-hc rt-u-%s\" title=\"%s\">%s%s</th>"
                       (layer_of_edge site) (esc slug)
                       (match stage with Canary_agreement_common.Pre -> "›" | Canary_agreement_common.Post -> "»")
                       (esc code)))) )
    in
    (* the rooting's tool and artifact, a tooltip on the R cell *)
    let rooting =
      List.map (CR.summary_rows ()) ~f:(fun sr -> (sr.CR.sr_slug, sr))
    in
    (* the verdict of the table's own checks, then the legend and the kind
       glossary, before the data *)
    (let v = CR.overview_verdict () in
     let bad =
       String.is_substring v ~substring:"VIOLATION"
       || String.is_substring v ~substring:"UNWATCHED"
     in
     Printf.sprintf "<p class=\"verdict%s\">%s</p>"
       (if bad then " bad" else "")
       (esc v))
    (* the laws themselves, as the registry states them *)
    ^ Printf.sprintf
        "<details class=\"laws\"><summary>The %d laws every row keeps</summary><ol>%s</ol></details>"
        (List.length CR.row_rules)
        (String.concat
           (List.map CR.row_rules ~f:(fun r ->
                Printf.sprintf "<li><b>%s</b> — %s</li>" (esc r.CR.rr_name) (esc r.CR.rr_says))))
    ^ "<dl class=\"legend\">"
    ^ "<dt>row order</dt><dd>trigger action, then agreement, then language, \
       then mechanism. The trigger is language-free: the columns put every \
       OCaml action before every Python one, so ranking on the column would \
       scatter one claim across the table. Unimplemented claims sort last, \
       because the table's first job is to say what canary can check.</dd>"
    ^ "<dt>code</dt><dd>the AGREEMENT's identity, so a repeated code is one \
       claim with several patterns, shown adjacent. It is the key to the \
       check columns of §1.2's result table, which has one column per \
       claim and none per pattern — which is why the code repeats rather \
       than being made unique per row.</dd>"
    ^ "<dt>one row per pattern</dt><dd>a claim whose firing differs between \
       mechanisms gets a row each; a uniform claim stays one row and says \
       so by leaving <b>mech</b> empty.</dd>"
    ^ "<dt>columns</dt><dd>§1.2's frames — each action as §1 draws it, \
       by side, then flow — so a row marks the very columns the result \
       table fills.</dd>"
    ^ "<dt>&#9635;</dt><dd>a NODE the claim reads, marked in the frames of \
       its site. A declaration is not a node, which is why some claims \
       show one.</dd>"
    ^ "<dt>R &middot; D &middot; R+D</dt><dd>on a piece: R = its rule RAN \
       there (hover for the tool and the artifact); D = a method FIRES \
       there; R+D = both — the site's piece in a frame that has it. A row \
       with no R roots in no action of this graph. R is placed in the row's \
       own language: the registry spells a root's action once, and a cext \
       row must not mark the OCaml column.</dd>"
    ^ "<dt>&#9670;</dt><dd>the claim's own check column: where §1.2 shows \
       its outcome.</dd>"
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
    ^ "<dt>sits on &middot; where</dt><dd>WHERE THE CLAIM SITS ON THE CHAIN \
       — the diagram's edges it sits on (its claim site), then the layers \
       their ends lie in and how far it reaches: one side's own chain, \
       across the two sides, or end to end. The same claim sites give the \
       diagram its badges; the table under this one groups every agreement \
       by them.</dd>"
    ^ "<dt>lag</dt><dd>action columns from the root to the nearest firing. \
       NOT the distance between the two SIDES of a comparison, which is a \
       different measure.</dd>"
    ^ "<dt>decided &middot; blame</dt><dd>counted over §1.2's cells, one \
       per chain, so a library's verdict counts once in each language it \
       serves. <b>decided</b>: ✓ held, ✗ violated. <b>blame</b>: whose \
       defect a cell is — every undecided cell's, and a violation's where \
       one declared value stands for several versions; glossed below.</dd>"
    ^ "<dt>kind</dt><dd>what the claim ASSERTS — the six values are \
       glossed just below, next to the table that uses them.</dd>"
    ^ "</dl>"
    ^ "<p class=\"kq\">One note that belongs here because it misleads in \
       the cell: <code>soname</code> is an ELF word for a format-neutral fact, the \
       library's own recorded identity — <code>DT_SONAME</code> on ELF and \
       the <code>LC_ID_DYLIB</code> install name on Mach-O, which the \
       inspector writes into one field. Those claims are NOT elf-only; the \
       two version-node ones are.</p>"
    ^ "<p class=\"kq\">blame: "
    ^ String.concat ~sep:" &middot; "
        (List.map M.blame_gloss ~f:(fun (w, g) ->
             "<b>" ^ esc w ^ "</b> " ^ esc g))
    ^ "</p>"
    (* each label a log records, the mark §1.2 shows for it, and the
       blame [blame_of] can give it, over the cases it distinguishes *)
    ^ E.table ~cls:"okey" "tab-outcomes"
    ^ "<tr><th>a log records</th><th>meaning</th>\
       <th>§1.2 shows</th><th>blame</th></tr>"
    ^ String.concat
        (List.map M.outcome_marks ~f:(fun o ->
             let blames =
               List.map [ (false, false); (false, true); (true, false); (true, true) ]
                 ~f:(fun (is_declaration, version_blind) ->
                   M.blame_of ~outcome:o.M.om_label ~is_declaration ~version_blind)
               |> List.dedup_and_sort ~compare:(Option.compare String.compare)
               |> List.map ~f:(function None -> "—" | Some b -> b)
             in
             Printf.sprintf "<tr><td><code>%s</code></td><td>%s</td><td>%s</td><td>%s</td></tr>"
               (esc o.M.om_label) (esc o.M.om_means) (esc o.M.om_mark)
               (esc (String.concat ~sep:" or " blames))))
    ^ "</table>"
    ^ "<div class=\"kinds\"><b>kind</b> — what the claim ASSERTS; not what \
       it is held against (the record's <code>against</code>), and not \
       whose rule it recovers (the <b>R</b> column)."
    ^ "<dl>"
    ^ "<dt>admissibility</dt><dd>would ONE action have accepted these \
       artifacts together as its inputs? <code>agreement/README.md</code> §5.2's \
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
    ^ (let sides, frame_labels, columns = frame_head in
       E.table ~cls:"keytbl grid" "tab-agreements"
       ^ "<thead><tr>"
       ^ String.concat
           (List.map
              [ "code"; "agreement"; "kind"; "implemented at"; "lang"; "mech"; "object";
                "sits on"; "where" ]
              ~f:(fun h -> "<th rowspan=\"3\">" ^ h ^ "</th>"))
       ^ sides
       ^ "<th rowspan=\"3\">lag</th><th rowspan=\"3\">decided</th><th rowspan=\"3\">blame</th></tr>"
       ^ "<tr>" ^ frame_labels ^ "</tr><tr>" ^ columns ^ "</tr></thead><tbody>")
    ^ String.concat ~sep:""
        (List.map rows ~f:(fun (row : CR.overview_row) ->
             let r = row.CR.ov_agreement in
             (* an external row is the same claim answered by an existing
                tool; its code carries a `*` *)
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
             (* where the code is: the evaluator, or a red cell naming the
                file it would go in; the tooltip names the declaration *)
             let family, fn = CR.impl_of r in
             let impl_cell =
               match fn with
               | Some f ->
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
             (* the axis cells state this row's reach: the claim's, or the
                tool's for an external row *)
             ^ esc (CR.row_lang_label row)
             ^ "</td><td class=\"lm\">"
             ^ esc (CR.row_mech_label row)
             ^ "</td><td class=\"mk\">" ^ esc (CR.row_format_label row) ^ "</td>"
             (* where it sits on the chain: its claim site's edges, then
                the layers and how far it reaches *)
             ^ (match Canary_topology.sitting_of r.CR.ag_slug with
                | Some s ->
                    Printf.sprintf
                      "<td class=\"lm site\">%s</td><td class=\"lm where\" \
                       title=\"%s\">%s · %s</td>"
                      (esc (String.concat ~sep:", " s.Canary_topology.st_edges))
                      (esc (Canary_topology.string_of_reach s.Canary_topology.st_reach))
                      (esc (Canary_topology.string_of_layers s.Canary_topology.st_layers))
                      (esc (Canary_topology.string_of_reach s.Canary_topology.st_reach))
                | None ->
                    "<td class=\"lm site none\">not placed</td><td class=\"lm where\"></td>")
             (* the claim in the frames: ▣, R, D and its own column *)
             ^ String.concat ~sep:""
                 (List.concat_map (Fr.row_marks row) ~f:(fun marks ->
                      List.map marks ~f:(function
                        | "▣" -> "<td class=\"g tgt\">&#9635;</td>"
                        | "R" -> Printf.sprintf "<td class=\"g rr\"%s>R</td>" root_title
                        | "D" -> "<td class=\"g dd\">D</td>"
                        | "R+D" -> Printf.sprintf "<td class=\"g rd\"%s>R+D</td>" root_title
                        | "◆" -> "<td class=\"g own\">&#9670;</td>"
                        | _ -> "<td class=\"g nn\"></td>")))
             ^ "<td>"
             ^ (match CR.row_lag row with
                | Some d -> Int.to_string d
                | None -> "<span class=\"kq\">—</span>")
             (* decided and blame are what our runs recorded: empty for an
                external row *)
             ^ "</td><td>"
             ^ (match ext with
                | None -> tally r.CR.ag_slug
                | Some _ -> "<span class=\"kq\">—</span>")
             ^ "</td><td>"
             ^ (match ext with
                | None -> blame_tally r.CR.ag_slug
                | Some _ -> "")
             ^ "</td></tr>"))
    ^ "</tbody></table>"
    ^ sittings_html
  in
  recovery_grid

(** §2's stylesheet, [canary/overview/agreements.css], written against the
    page's colour tokens. *)
let css () = Canary_overview_assets.read "agreements.css"

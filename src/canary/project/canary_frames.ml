(** THE COLUMN MODEL shared by the result table and the agreement overview
    (2026-09-28, user: design/overview.md §6.4, prototype A — "A and the
    rest looks good").

    The user's point: the old columns put a world's artifacts first and
    then only actions, so the table said where an artifact came from and
    never which action consumed or produced it. A FRAME is one action as
    the diagram draws it: what it consumes, the checks on that input, the
    action, what it produced, the checks on that product. An artifact
    appears again in every frame that consumes it.

    Everything here is DERIVED from the overview's graph
    ({!Canary_topology.edges} and {!Canary_topology.nodes}) and from the
    registry ({!Canary_topology.claim_sites}, each agreement's slot), so
    the header cannot say something the diagram does not:

    - a frame is a CONNECTED group of one action family's edges — so
      [probe_binding]'s two consumers, which share no node, are two
      frames, and [fetch_binding]'s resolve, bridge and install pieces are
      one;
    - sibling edges with the same inputs are one PIECE, realized by one
      step ([realize_sys] and [realize_hdr] are the fetch's [realize]);
    - pieces run in flow order, and frames sit by side — the system side,
      the binding, the language side, the program — then by flow;
    - an agreement with an evaluator has a check column at each of its
      site edges: a verdict on what the piece made goes after the piece's
      products; a requirement goes before the piece that makes the
      frame's artifacts, or after its site's products where the
      requirement is a later action's.

    The oracle is the layout the user confirmed:
    [frames.derive_the_confirmed_layout]. *)

open Base
module T = Canary_topology
module C = Canary_agreement_common
module A = Canary_agreement
module F = Canary_action_family

(** Where a frame sits, in the order the table reads: the diagram's system
    side on the left, the binding between the two sides, the language
    side on the right, then the program row under them. *)
type side = System | Binding | Language | Program

let string_of_side = function
  | System -> "system"
  | Binding -> "binding"
  | Language -> "language"
  | Program -> "program"

let side_rank = function System -> 0 | Binding -> 1 | Language -> 2 | Program -> 3

(** How a table's header names the side — one spelling for both tables. *)
let label_of_side = function
  | System -> "system side"
  | Binding -> "binding"
  | Language -> "language side"
  | Program -> "program"

type column =
  | Node of string  (** a node of the diagram, by id *)
  | Piece of { edges : string list; label : string }
      (** the sibling edges one step realizes together *)
  | Check of { slug : string; code : string; site : string; stage : C.stage }
      (** one agreement at one of its site edges *)

type frame = {
  fr_family : F.t;
  fr_side : side;
  fr_label : string;
  fr_columns : column list;
}

(* ── the graph, as this module reads it ── *)

let action_edges : (T.edge * F.t) list =
  List.filter_map T.edges ~f:(fun e ->
      match e.T.eg_annotation with T.Action f -> Some (e, f) | _ -> None)

(* the hand order of the diagram's edge list, which is the tie-break
   wherever the flow leaves a choice *)
let edge_index (id : string) : int =
  match List.findi T.edges ~f:(fun _ e -> String.equal e.T.eg_id id) with
  | Some (i, _) -> i
  | None -> Int.max_value

let layer_of (n : string) = Option.map (T.node_by_id n) ~f:(fun nd -> nd.T.nd_layer)
let side_of_node (n : string) = Option.map (T.node_by_id n) ~f:(fun nd -> nd.T.nd_side)
let nodes_of_edge (e : T.edge) = e.T.eg_to :: e.T.eg_from
let mem = List.mem ~equal:String.equal

(* ── frames: a family's edges, split where they share no node ── *)

let components (es : T.edge list) : T.edge list list =
  let touches e comp =
    List.exists comp ~f:(fun c -> List.exists (nodes_of_edge e) ~f:(mem (nodes_of_edge c)))
  in
  let rec grow comp rest =
    let near, far = List.partition_tf rest ~f:(fun e -> touches e comp) in
    if List.is_empty near then (comp, rest) else grow (comp @ near) far
  in
  let rec go acc = function
    | [] -> List.rev acc
    | e :: rest ->
        let comp, rest = grow [ e ] rest in
        let comp =
          List.sort comp ~compare:(fun a b ->
              Int.compare (edge_index a.T.eg_id) (edge_index b.T.eg_id))
        in
        go (comp :: acc) rest
  in
  go [] es

(* ── pieces: sibling edges, in flow order ── *)

type piece = { p_edges : T.edge list; p_from : string list; p_to : string list }

(* SIBLINGS: the same inputs, and products in the same layer. The layer
   matters: [depends] and [install_lang] both start from the binding
   package, but one pulls in a bridge package and the other places the
   binding's artifacts — two pieces, not one *)
let pieces_of (comp : T.edge list) : piece list =
  let same_layer a b = Poly.equal (layer_of a) (layer_of b) in
  List.fold comp ~init:[] ~f:(fun acc e ->
      match
        List.findi acc ~f:(fun _ p ->
            List.equal String.equal p.p_from e.T.eg_from
            && List.for_all p.p_to ~f:(same_layer e.T.eg_to))
      with
      | Some (i, _) ->
          List.mapi acc ~f:(fun j p ->
              if j = i then { p with p_edges = p.p_edges @ [ e ]; p_to = p.p_to @ [ e.T.eg_to ] }
              else p)
      | None -> acc @ [ { p_edges = [ e ]; p_from = e.T.eg_from; p_to = [ e.T.eg_to ] } ])

let piece_index (p : piece) : int =
  List.fold p.p_edges ~init:Int.max_value ~f:(fun m e -> Int.min m (edge_index e.T.eg_id))

(** A piece's name: its edge's, without the side suffix the diagram needs
    and a frame does not; for sibling edges, the words they share
    ([realize_sys] and [realize_hdr] are [realize]). *)
let piece_label (p : piece) : string =
  let strip id =
    match String.chop_suffix id ~suffix:"_sys" with
    | Some s -> s
    | None -> Option.value (String.chop_suffix id ~suffix:"_lang") ~default:id
  in
  match List.map p.p_edges ~f:(fun e -> e.T.eg_id) with
  | [ id ] -> strip id
  | ids ->
      let words = List.map ids ~f:(String.split ~on:'_') in
      let rec common = function
        | (w :: _) :: _ as ws
          when List.for_all ws ~f:(function x :: _ -> String.equal x w | [] -> false) ->
            w :: common (List.map ws ~f:List.tl_exn)
        | _ -> []
      in
      (match common words with [] -> String.concat ~sep:"+" ids | c -> String.concat ~sep:"_" c)

(** Flow order: a piece that makes what another consumes goes first; the
    diagram's edge order breaks ties. A self-loop ([probe_lib] reads the
    library it names) feeds nothing. *)
let order_by ~(feeds : 'a -> 'a -> bool) ~(index : 'a -> int) (xs : 'a list) : 'a list =
  let rec go acc remaining =
    match remaining with
    | [] -> List.rev acc
    | _ ->
        let ready =
          List.filter remaining ~f:(fun b ->
              not (List.exists remaining ~f:(fun a -> (not (phys_equal a b)) && feeds a b)))
        in
        (* a cycle falls back to the diagram's order rather than looping *)
        let ready = if List.is_empty ready then remaining else ready in
        let next =
          List.min_elt ready ~compare:(fun a b -> Int.compare (index a) (index b))
          |> Option.value_exn
        in
        go (next :: acc) (List.filter remaining ~f:(fun x -> not (phys_equal x next)))
  in
  go [] xs

let order_pieces (ps : piece list) : piece list =
  order_by ps ~index:piece_index ~feeds:(fun a b -> List.exists a.p_to ~f:(mem b.p_from))

(* ── where a frame sits ── *)

let frame_side (ps : piece list) : side =
  let tos = List.concat_map ps ~f:(fun p -> p.p_to) in
  let froms = List.concat_map ps ~f:(fun p -> p.p_from) in
  let at l s n = Poly.equal (layer_of n) (Some l) && Poly.equal (side_of_node n) (Some s) in
  if List.exists tos ~f:(fun n -> Poly.equal (layer_of n) (Some T.L_program)) then Program
  else if List.for_all (tos @ froms) ~f:(fun n -> Poly.equal (side_of_node n) (Some T.S_sys))
  then System
  (* the binding joins the two sides' artifacts: it makes a language-side
     artifact out of a system-side one *)
  else if
    List.exists tos ~f:(at T.L_artifact T.S_lang)
    && List.exists froms ~f:(at T.L_artifact T.S_sys)
  then Binding
  else Language

(* ── the checks ── *)

(** The agreements a table can fill: a registry row with an evaluator. A
    planned one would be a column of dots, and a candidate is not a row. *)
let checked_rows : A.agreement_row list =
  List.filter A.agreement_registry ~f:(fun r ->
      match A.status_of_row r with
      | A.Evaluated | A.Partly -> true
      | A.Planned_only | A.Off_in_registry | A.Proposed -> false)

let sites_of (slug : string) : string list =
  List.concat_map T.claim_sites ~f:(fun cs ->
      if String.equal cs.T.cs_claim slug then cs.T.cs_edges else [])

(** An agreement's preferred slot: what action it guards or judges, and
    which. Language-free in everything a frame asks of it, so OCaml's
    spelling stands for all. *)
let slot_of (r : A.agreement_row) : (Canary_basic.action * C.stage) option =
  List.hd (r.A.ag.C.ag_slot Canary_lang.OCaml)

type placement = Before of piece | After of piece

(** Where a check at [site] goes in a frame of [family] whose pieces are
    [ps]. A verdict on what the site made goes after the site's products.
    A requirement of this frame's action goes before the piece that makes
    the frame's artifacts — the first such piece from its site on, so a
    gate checked by one piece and needed by the next reads between them.
    A requirement of a LATER action judges what the site made for it, and
    goes after the site's products. *)
let placement ~(family : F.t) ~(ps : piece list) ~(site : piece) (stage : C.stage)
    ~(slot_family : F.t option) : placement =
  match stage with
  | C.Post -> After site
  | C.Pre -> (
      match slot_family with
      | Some f when F.equal f family -> (
          let makes_artifact p =
            List.exists p.p_to ~f:(fun n -> Poly.equal (layer_of n) (Some T.L_artifact))
          in
          let from_site = List.drop_while ps ~f:(fun p -> not (phys_equal p site)) in
          match List.find from_site ~f:makes_artifact with
          | Some p -> Before p
          | None -> After site)
      | _ -> After site)

let checks_in (family : F.t) (ps : piece list) : (placement * column) list =
  List.concat_map checked_rows ~f:(fun r ->
      match slot_of r with
      | None -> []
      | Some (slot_action, stage) ->
          let slot_family = Some (F.of_action slot_action) in
          List.filter_map (sites_of r.A.ag_slug) ~f:(fun site ->
              Option.map
                (List.find ps ~f:(fun p ->
                     List.exists p.p_edges ~f:(fun e -> String.equal e.T.eg_id site)))
                ~f:(fun p ->
                  ( placement ~family ~ps ~site:p stage ~slot_family,
                    Check
                      { slug = r.A.ag_slug;
                        code = C.short_code_of_slug r.A.ag_slug;
                        site;
                        stage } ))))

(* ── the columns of one frame ── *)

let columns_of (family : F.t) (ps : piece list) : column list =
  let checks = checks_in family ps in
  let placed pl =
    List.filter_map checks ~f:(fun (p, c) -> if Poly.equal p pl then Some c else None)
    |> List.sort ~compare:(fun a b ->
           match (a, b) with
           | Check x, Check y -> String.compare x.code y.code
           | _ -> 0)
  in
  let seen = ref [] in
  let nodes ns =
    List.filter_map ns ~f:(fun n ->
        if mem !seen n then None
        else (
          seen := !seen @ [ n ];
          Some (Node n)))
  in
  List.concat_map ps ~f:(fun p ->
      let inputs = nodes p.p_from in
      let before = placed (Before p) in
      let piece =
        Piece { edges = List.map p.p_edges ~f:(fun e -> e.T.eg_id); label = piece_label p }
      in
      let outputs = nodes p.p_to in
      inputs @ before @ [ piece ] @ outputs @ placed (After p))

(* ── the model ── *)

(** Every frame, in table order. *)
let frames : frame list =
  let families =
    List.fold action_edges ~init:[] ~f:(fun acc (_, f) ->
        if List.mem acc f ~equal:F.equal then acc else acc @ [ f ])
  in
  let raw =
    List.concat_map families ~f:(fun f ->
        let es = List.filter_map action_edges ~f:(fun (e, g) -> if F.equal f g then Some e else None) in
        let comps = components es in
        List.map comps ~f:(fun comp ->
            let ps = order_pieces (pieces_of comp) in
            let label =
              match comps with
              | [ _ ] -> F.to_string f
              | _ -> F.to_string f ^ " · " ^ piece_label (List.last_exn ps)
            in
            (f, ps, label)))
  in
  (* a frame goes after another that makes something it consumes from
     outside itself. A piece that reads what it names ([probe_lib]'s
     self-loop) makes nothing *)
  let produces (_, ps, _) =
    List.concat_map ps ~f:(fun p -> List.filter p.p_to ~f:(fun n -> not (mem p.p_from n)))
  in
  let consumes (_, ps, _) =
    let own = List.concat_map ps ~f:(fun p -> p.p_to) in
    List.concat_map ps ~f:(fun p -> p.p_from) |> List.filter ~f:(fun n -> not (mem own n))
  in
  let index (_, ps, _) = List.fold ps ~init:Int.max_value ~f:(fun m p -> Int.min m (piece_index p)) in
  let sided = List.map raw ~f:(fun ((_, ps, _) as x) -> (frame_side ps, x)) in
  List.concat_map [ System; Binding; Language; Program ] ~f:(fun side ->
      List.filter_map sided ~f:(fun (s, x) -> if Poly.equal s side then Some x else None)
      |> order_by ~index ~feeds:(fun a b -> List.exists (produces a) ~f:(mem (consumes b)))
      |> List.map ~f:(fun (f, ps, label) ->
             { fr_family = f; fr_side = side; fr_label = label; fr_columns = columns_of f ps }))

(* ── §2 on the same header (2026-09-28, design/overview.md §6.4 step 4) ── *)

(** WHICH NODE OF THE DIAGRAM AN EVIDENCE REFERENCE IS ABOUT — the
    node-level refinement of [Canary_agreement_common.artifacts_of_input].
    The artifact kinds are coarser than the diagram: the binding is one
    kind and three nodes (its stub, its module, its surface), and a
    bridge record is about two packages, the bridge and the capability
    file its check reads, which no artifact kind names. Here each
    reference names the nodes it is read from, so §2 can mark a claim's
    targets in the frames. *)
let nodes_of_input : C.inspect_input -> string list = function
  | C.Native_lib _ | C.Versioned_exports _ -> [ "lib_sys" ]
  | C.Staged_lib _ -> [ "staged_sys" ]
  | C.Typed_header _ -> [ "hdr_sys" ]
  | C.C_stub _ -> [ "stub_lang" ]
  (* a stub's signatures are scanned from its source *)
  | C.Typed_binding_stub _ -> [ "src_lang" ]
  (* what a consumer recorded: the stub archive or the extension module,
     whichever the mechanism makes *)
  | C.Versioned_req _ | C.Abi_surface _ -> [ "stub_lang"; "mod_lang" ]
  | C.Ocaml_mli _ | C.Python_attrs _ | C.Typed_binding_user _ -> [ "surf_lang" ]
  | C.Bridge_record _ -> [ "bridge"; "cap" ]
  | C.Declared_exports _ | C.Declared_soname _ | C.Declared_version_tags _ -> []

(** One §2 row's marks, per frame and per column: [▣] a node the claim
    reads, in the frames of its site; [R] the piece where its rule ran,
    [D] where a method fires ([R+D] both) — the site's piece in a frame
    that has it, else the frame's last piece; [◆] its own check column.
    Empty where nothing applies. The row's R and D are the overview's own
    ({!Canary_agreement.overview_rows}, over a built world), so the two
    views of one claim cannot place them differently. *)
let row_marks (row : A.overview_row) : string list list =
  let r = row.A.ov_agreement in
  let slug = r.A.ag_slug in
  let sites = sites_of slug in
  let mechanism =
    match row.A.ov_mechs with m :: _ -> m | [] -> Canary_mechanism.Cstubs
  in
  let lang = (Canary_mechanism.info_of_mechanism mechanism).Canary_mechanism.mi_lang in
  let ctx =
    { C.ac_mechanism = mechanism;
      ac_lang = lang;
      ac_world = C.uniform_world ~lang ~mechanism Canary_store.Built;
      ac_declared = None }
  in
  let targets =
    List.concat_map r.A.ag.C.ag_methods ~f:(fun m -> m.C.m_inputs ctx)
    |> List.concat_map ~f:nodes_of_input
  in
  let families pred =
    List.filter_map row.A.ov_cells ~f:(fun (a, mk) -> if pred mk then Some (F.of_action a) else None)
  in
  let rooted = families (function A.Rooted | A.Rooted_and_detected -> true | _ -> false) in
  let detected = families (function A.Detected | A.Rooted_and_detected -> true | _ -> false) in
  List.map frames ~f:(fun fr ->
      let pieces =
        List.filter_map fr.fr_columns ~f:(function Piece { edges; _ } -> Some edges | _ -> None)
      in
      let site_piece = List.find pieces ~f:(List.exists ~f:(mem sites)) in
      let marked = match site_piece with Some p -> Some p | None -> List.last pieces in
      let at fams edges =
        List.mem fams fr.fr_family ~equal:F.equal
        && Option.exists marked ~f:(List.equal String.equal edges)
      in
      List.map fr.fr_columns ~f:(function
        | Node n -> if Option.is_some site_piece && mem targets n then "▣" else ""
        | Piece { edges; _ } -> (
            match (at rooted edges, at detected edges) with
            | true, true -> "R+D"
            | true, false -> "R"
            | false, true -> "D"
            | false, false -> "")
        | Check { slug = s; _ } -> if String.equal s slug then "◆" else ""))

(* ── printing ── *)

let string_of_column = function
  | Node n -> n
  | Piece { label; _ } -> "▸" ^ label
  | Check { code; stage; _ } -> (match stage with C.Pre -> "›" | C.Post -> "»") ^ code

let pp_frame (fr : frame) : string =
  Printf.sprintf "%s %s: %s" (string_of_side fr.fr_side) fr.fr_label
    (String.concat ~sep:" " (List.map fr.fr_columns ~f:string_of_column))

let pp () : string = String.concat ~sep:"\n" (List.map frames ~f:pp_frame)

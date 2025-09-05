open Langs
open Dd
open Graph

module Node = struct
  type t =
    | V_clo of Dd_val.With_closure.t * call_stack
    | Def of Id.t * call_stack
    | Use of Id.t * call_stack
    | Exp of exp * call_stack
    | Cs of call_stack
  [@@deriving eq, ord]

  let hash = Hashtbl.hash

  let get_cs = function
    | V_clo (_, cs) -> cs
    | Def (_, cs) -> cs
    | Use (_, cs) -> cs
    | Exp (_, cs) -> cs
    | Cs cs -> cs

  let str_of_cs cs = Fmt.str "@[<h>%a@]" Dd.pp_cs_compact cs

  let pp oc = function
    | V_clo (v, cs) ->
        Dd_val.With_closure.pp_compact oc v;
        Dd.pp_cs oc cs
    | Def (x, cs) | Use (x, cs) ->
        Id.pp oc x;
        Dd.pp_cs oc cs
    | Exp (e, cs) ->
        Dd.pp_exp_compact oc e;
        Dd.pp_cs oc cs
    | Cs cs -> Dd.pp_cs oc cs
end

module G = Imperative.Digraph.Concrete (Node)

(* Printing *)

module type With_title = sig
  val title : string
end

module DotPrinter_Make (T : With_title) = struct
  include Graph.Graphviz.Dot (struct
    include G
    module C = Color_brewery

    let vertex_name v =
      let n = V.label v in
      Fmt.str "@[<h>\"%a\"@]" Node.pp n

    let graph_attributes _ = [ `Rankdir `BottomToTop (* `Label T.title  *) ]
    let default_vertex_attributes _ = []

    let vertex_attributes v =
      let colors =
        let ci =
          match V.label v with
          | V_clo (_, _) -> 0
          | Def (_, _) -> 1
          | Use (_, _) -> 2
          | Exp (_, _) -> 3
          | Cs _ -> 4
        in
        let cp = List.nth C.Palette.rdbu 5 in
        [ `Color (C.Palette.(get_rgb cp ci) |> C.to_int) ]
      in
      let shapes =
        match V.label v with
        | Cs _ -> [ `Shape `Box ]
        | Use _ -> [ `Shape `Diamond ]
        | _ -> []
      in

      colors @ shapes

    let default_edge_attributes _ = []
    let edge_attributes _ = []

    let get_subgraph v =
      let open Graphviz.DotAttributes in
      let cso =
        let open Node in
        match v with
        | Def (_, cs) -> Some cs
        | Use (_, cs) -> Some cs
        | Cs cs -> Some cs
        | _ -> None
      in
      Option.map
        (fun cs ->
          { sg_name = Node.str_of_cs cs; sg_attributes = []; sg_parent = None })
        cso

    (* let sg_parent =
         if List.length cs = 0 then None else Some (Node.str_of_cs (List.tl cs))
       in *)
  end)
end

let dot_output g title f =
  let module DP =
    DotPrinter_Make
      ((val (module struct
              let title = title
            end)
           : With_title)) in
  let oc = open_out f in
  DP.output_graph oc g;
  close_out oc

let display_with_gv g =
  let tmp = Filename.temp_file "graph" ".dot" in
  dot_output g "" tmp;
  ignore (Sys.command ("dot -Tps " ^ tmp ^ " | gv -"));
  Sys.remove tmp

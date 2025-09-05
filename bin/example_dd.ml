open Interp
module V_clo = Dd_val.With_closure
module V_dd = Dd_val.With_callstack
open Langs

let () =
  (* let e = Example.Dd_example.sum_3_4 |> Lang.Dd.assign_labal in *)
  (* let e = Example.Dd_example.e7 |> Lang.Dd.assign_labal in *)
  let e = Example.Dd_example.countcount3 |> Dd.assign_labal in
  Fmt.pr "%a@." Dd.pp_exp e;
  let g, v1 = Dd_interp_subst_graph.interp e in
  Fmt.pr "%a@." Dd.pp_exp v1;
  Dd_graph.dot_output g "Binding graph of a subst interpreter"
    "out/graph_subst.dot";
  let g, v2 = Dd_interp_env_graph.interp e in
  Fmt.pr "%a@." V_clo.pp v2;
  Dd_graph.dot_output g "Binding graph of a env interpreter" "out/graph_env.dot";

  let g, v3 = Dd_interp_lazy_env.interp e in
  Fmt.pr "%a@." V_dd.pp v3;
  Dd_graph.dot_output g "Binding graph of a dd interpreter" "out/graph_dd.dot";
  ()

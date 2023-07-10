include Std_core

module Printing = struct
  let pp_table table_iter pp_elem oc s =
    Fmt.(vbox @@ iter_bindings ~sep:nop table_iter (pair string pp_elem)) oc s

  (* let pp_table ?(name = "set") iter pp_elem oc s =
     let pp_name oc _ = Fmt.string oc name in
     (Fmt.Dump.iter_bindings iter pp_name Fmt.(string ++ cut) pp_elem) oc s *)
end

include Printing

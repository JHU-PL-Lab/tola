open Z3

let () =
  let ctx = mk_context [] in
  let x = Arithmetic.Integer.mk_const ctx (Symbol.mk_string ctx "x") in
  let solver = Solver.mk_solver ctx None in
  Solver.add solver [ Arithmetic.mk_gt ctx x (Arithmetic.Integer.mk_numeral_i ctx 0) ];
  let status = Solver.check solver [] in
  Printf.printf "z3 version: %s\n" Version.to_string;
  Printf.printf "sat status: %s\n" (Solver.string_of_status status)

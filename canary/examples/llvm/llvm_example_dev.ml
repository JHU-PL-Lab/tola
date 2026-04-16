open Llvm

(* Uses Opcode.UncondBr introduced when LLVM split `br` into `uncondbr` and
   `condbr` (LLVM 21+, commit #186176, March 2026).
   Compiles against dev binding; fails with LLVM 19 ("Unbound constructor Opcode.UncondBr"). *)
let () =
  let ctx = create_context () in
  let m = create_module ctx "canary_llvm_dev" in
  let ft = function_type (void_type ctx) [||] in
  let f = define_function "entry" ft m in
  let bb0 = entry_block f in
  let bb1 = append_block ctx "exit" f in
  let b0 = builder_at_end ctx bb0 in
  let br_inst = build_br bb1 b0 in
  let b1 = builder_at_end ctx bb1 in
  ignore (build_ret_void b1);
  assert (instr_opcode br_inst = Opcode.UncondBr);
  print_string (string_of_llmodule m);
  dispose_module m;
  dispose_context ctx

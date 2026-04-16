open Llvm

(* Uses Opcode.Br present in LLVM 19 and earlier.
   In LLVM 21+ (commit #186176, March 2026), Opcode.Br was replaced by
   Opcode.Invalid3 + new Opcode.UncondBr / Opcode.CondBr.
   Compiles against LLVM 19 binding; fails with dev ("Unbound constructor Opcode.Br"). *)
let () =
  let ctx = create_context () in
  let m = create_module ctx "canary_llvm_19" in
  let ft = function_type (void_type ctx) [||] in
  let f = define_function "entry" ft m in
  let bb0 = entry_block f in
  let bb1 = append_block ctx "exit" f in
  let b0 = builder_at_end ctx bb0 in
  let br_inst = build_br bb1 b0 in
  let b1 = builder_at_end ctx bb1 in
  ignore (build_ret_void b1);
  assert (instr_opcode br_inst = Opcode.Br);
  print_string (string_of_llmodule m);
  dispose_module m;
  dispose_context ctx

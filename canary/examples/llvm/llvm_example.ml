open Llvm

let () =
  let context = create_context () in
  let m = create_module context "canary_llvm" in
  let i32_t = i32_type context in
  let fn_t = function_type i32_t [||] in
  ignore (declare_function "answer" fn_t m);
  print_endline (string_of_llmodule m)

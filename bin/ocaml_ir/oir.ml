open Langs

let source_file = Sys.argv.(1)

let info : Compile_common.info =
  let tool_name = "tool" in
  let output_prefix = "pre" in
  Common.mk_info ~tool_name ~source_file ~output_prefix

let i = info

(* Parsing *)
let ast = Lexing.from_channel @@ open_in source_file
let impl = Parse.implementation ast
let _ = Printast.implementation Format.std_formatter impl;;

if !Clflags.classic_inlining then (
  Clflags.default_simplify_rounds := 1;
  Clflags.use_inlining_arguments_set Clflags.classic_arguments;
  Clflags.unbox_free_vars_of_closures := false;
  Clflags.unbox_specialised_args := false)

(* Typing *)
let typed =
  Typemod.type_implementation i.source_file i.output_prefix i.module_name i.env
    impl

let () = Printtyped.implementation_with_coercion i.ppf_dump typed
let ( |>> ) (x, y) f = (x, f y)
let backend = Common.backend

let lprogram, clambda_with_constants, fcode =
  (* let () = *)
  let Typedtree.{ structure; coercion; _ } = typed in
  let lprogram =
    Translmod.transl_implementation_flambda i.module_name (structure, coercion)
  in

  (* if !Clflags.classic_inlining then (
     Clflags.default_simplify_rounds := 1;
     Clflags.use_inlining_arguments_set Clflags.classic_arguments;
     Clflags.unbox_free_vars_of_closures := false;
     Clflags.unbox_specialised_args := false); *)
  Compilenv.reset ?packname:!Clflags.for_package info.module_name;
  let { Lambda.module_ident; main_module_block_size; required_globals; code } =
    lprogram
  in
  let (code : Lambda.lambda) = Simplif.simplify_lambda code in
  let program : Lambda.program =
    { Lambda.module_ident; main_module_block_size; required_globals; code }
  in
  Ident.Set.iter Compilenv.require_global program.required_globals;
  let clambda_with_constants, fcode =
    let prefixname = "pre" in
    let ppf_dump = i.ppf_dump in
    Common.lambda_to_clambda' ~backend ~prefixname ~ppf_dump program
    (* lambda_to_flambda ...; flambda_to_clambda  *)
  in
  (* let () =
       Asmgen.compile_implementation ~backend ~prefixname:i.output_prefix
         ~middle_end:Flambda_middle_end.lambda_to_clambda ~ppf_dump:i.ppf_dump
         program;
       Compilenv.save_unit_info (cmx i)
     in *)
  (lprogram, clambda_with_constants, fcode)

let () =
  Printlambda.lambda i.ppf_dump lprogram.code;

  print_endline "\n-f-\n";

  Format.fprintf i.ppf_dump "@ %a@." Flambda.print_program fcode;

  print_endline "\n-c-\n";

  let (ulambda, _, structured_constants) : Clambda.with_constants =
    clambda_with_constants
  in
  Printclambda.clambda i.ppf_dump ulambda;
  List.iter
    (fun { Clambda.symbol; definition; _ } ->
      Format.fprintf i.ppf_dump "%s:@ %a@." symbol
        Printclambda.structured_constant definition)
    structured_constants

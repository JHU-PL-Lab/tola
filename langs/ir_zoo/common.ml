type info = Compile_common.info

let mk_info ~tool_name ~source_file ~output_prefix : info =
  Compmisc.init_path ();
  let module_name = "m" in
  let env = Compmisc.initial_env () in
  let ppf_dump = Format.std_formatter in
  let native = true in
  { module_name; output_prefix; env; source_file; ppf_dump; tool_name; native }

module Backend = struct
  (* See backend_intf.mli. *)
  let symbol_for_global' = Compilenv.symbol_for_global'

  let closure_symbol = Compilenv.closure_symbol

  let really_import_approx = Import_approx.really_import_approx

  let import_symbol = Import_approx.import_symbol

  let size_int = Arch.size_int

  let big_endian = Arch.big_endian

  let max_sensible_number_of_arguments =
    (* The "-1" is to allow for a potential closure environment parameter. *)
    Proc.max_arguments_for_tailcalls - 1
end

let backend = (module Backend : Backend_intf.S)

let lambda_to_flambda ~ppf_dump ~prefixname ~backend ~size ~module_ident
    ~module_initializer =
  Profile.record_call "flambda" (fun () ->
      let previous_warning_reporter = !Location.warning_reporter in
      let module WarningSet = Set.Make (struct
        type t = Location.t * Warnings.t

        let compare = Stdlib.compare
      end) in
      let warning_set = ref WarningSet.empty in
      let flambda_warning_reporter loc w =
        let elt = (loc, w) in
        if not (WarningSet.mem elt !warning_set) then (
          warning_set := WarningSet.add elt !warning_set;
          previous_warning_reporter loc w)
        else
          None
      in
      Misc.protect_refs
        [ Misc.R (Location.warning_reporter, flambda_warning_reporter) ]
        (fun () ->
          let pass_number = ref 0 in
          let round_number = ref 0 in
          let check flam =
            if !Clflags.flambda_invariant_checks then
              try Flambda_invariants.check_exn flam
              with exn ->
                Misc.fatal_errorf "After Flambda pass %d, round %d:@.%s:@.%a"
                  !pass_number !round_number (Printexc.to_string exn)
                  Flambda.print_program flam
          in
          let ( +-+ ) flam (name, pass) =
            incr pass_number;
            if !Clflags.dump_flambda_verbose then (
              Format.fprintf ppf_dump "@.PASS: %s@." name;
              Format.fprintf ppf_dump "Before pass %d, round %d:@ %a@."
                !pass_number !round_number Flambda.print_program flam;
              Format.fprintf ppf_dump "\n@?");
            let flam = Profile.record ~accumulate:true name pass flam in
            if !Clflags.flambda_invariant_checks then
              Profile.record ~accumulate:true "check" check flam;
            flam
          in
          Profile.record_call ~accumulate:true "middle_end" (fun () ->
              let flam =
                Profile.record_call ~accumulate:true "closure_conversion"
                  (fun () ->
                    module_initializer
                    |> Closure_conversion.lambda_to_flambda ~backend
                         ~module_ident ~size)
              in
              if !Clflags.dump_rawflambda then
                Format.fprintf ppf_dump "After closure conversion:@ %a@."
                  Flambda.print_program flam;
              check flam;
              let fast_mode flam =
                pass_number := 0;
                let round = 0 in
                flam
                +-+ ("lift_lets 1", Lift_code.lift_lets)
                +-+ ("Lift_constants", Lift_constants.lift_constants ~backend)
                +-+ ("Share_constants", Share_constants.share_constants)
                +-+ ( "Lift_let_to_initialize_symbol",
                      Lift_let_to_initialize_symbol.lift ~backend )
                +-+ ( "Inline_and_simplify",
                      Inline_and_simplify.run ~never_inline:false ~backend
                        ~prefixname ~round ~ppf_dump )
                +-+ ( "Remove_unused_closure_vars 2",
                      Remove_unused_closure_vars.remove_unused_closure_variables
                        ~remove_direct_call_surrogates:false )
                +-+ ("Ref_to_variables", Ref_to_variables.eliminate_ref)
                +-+ ( "Initialize_symbol_to_let_symbol",
                      Initialize_symbol_to_let_symbol.run )
              in
              let rec loop flam =
                pass_number := 0;
                let round = !round_number in
                incr round_number;
                if !round_number > Clflags.rounds () then
                  flam
                else
                  flam
                  (* Beware: [Lift_constants] must be run before any pass that
                     might duplicate strings. *)
                  +-+ ("lift_lets 1", Lift_code.lift_lets)
                  +-+ ("Lift_constants", Lift_constants.lift_constants ~backend)
                  +-+ ("Share_constants", Share_constants.share_constants)
                  +-+ ( "Remove_unused_program_constructs",
                        Remove_unused_program_constructs
                        .remove_unused_program_constructs )
                  +-+ ( "Lift_let_to_initialize_symbol",
                        Lift_let_to_initialize_symbol.lift ~backend )
                  +-+ ("lift_lets 2", Lift_code.lift_lets)
                  +-+ ( "Remove_unused_closure_vars 1",
                        Remove_unused_closure_vars
                        .remove_unused_closure_variables
                          ~remove_direct_call_surrogates:false )
                  +-+ ( "Inline_and_simplify",
                        Inline_and_simplify.run ~never_inline:false ~backend
                          ~prefixname ~round ~ppf_dump )
                  +-+ ( "Remove_unused_closure_vars 2",
                        Remove_unused_closure_vars
                        .remove_unused_closure_variables
                          ~remove_direct_call_surrogates:false )
                  +-+ ("lift_lets 3", Lift_code.lift_lets)
                  +-+ ( "Inline_and_simplify noinline",
                        Inline_and_simplify.run ~never_inline:true ~backend
                          ~prefixname ~round ~ppf_dump )
                  +-+ ( "Remove_unused_closure_vars 3",
                        Remove_unused_closure_vars
                        .remove_unused_closure_variables
                          ~remove_direct_call_surrogates:false )
                  +-+ ("Ref_to_variables", Ref_to_variables.eliminate_ref)
                  +-+ ( "Initialize_symbol_to_let_symbol",
                        Initialize_symbol_to_let_symbol.run )
                  |> loop
              in
              let back_end flam =
                flam
                +-+ ( "Remove_unused_closure_vars",
                      Remove_unused_closure_vars.remove_unused_closure_variables
                        ~remove_direct_call_surrogates:true )
                +-+ ("Lift_constants", Lift_constants.lift_constants ~backend)
                +-+ ("Share_constants", Share_constants.share_constants)
                +-+ ( "Remove_unused_program_constructs",
                      Remove_unused_program_constructs
                      .remove_unused_program_constructs )
              in
              let flam =
                if !Clflags.classic_inlining then
                  fast_mode flam
                else
                  loop flam
              in
              let flam = back_end flam in
              (* Check that there aren't any unused "always inline" attributes. *)
              Flambda_iterators.iter_apply_on_program flam ~f:(fun apply ->
                  match apply.inline with
                  | Default_inline | Never_inline | Hint_inline -> ()
                  | Always_inline ->
                      (* CR-someday mshinwell: consider a different error message if
                         this triggers as a result of the propagation of a user's
                         attribute into the second part of an over application
                         (inline_and_simplify.ml line 710). *)
                      Location.prerr_warning
                        (Debuginfo.to_location apply.dbg)
                        (Warnings.Inlining_impossible
                           "[@inlined] attribute was not used on this function \
                            application (the optimizer did not know what \
                            function was being applied)")
                  | Unroll _ ->
                      Location.prerr_warning
                        (Debuginfo.to_location apply.dbg)
                        (Warnings.Inlining_impossible
                           "[@unrolled] attribute was not used on this \
                            function application (the optimizer did not know \
                            what function was being applied)"));
              if !Clflags.dump_flambda then
                Format.fprintf ppf_dump "End of middle end:@ %a@."
                  Flambda.print_program flam;
              check flam;
              (* CR-someday mshinwell: add -d... option for this *)
              (* dump_function_sizes flam ~backend; *)
              flam)))

let flambda_raw_clambda_dump_if ppf
    ({
       Flambda_to_clambda.expr = ulambda;
       preallocated_blocks = _;
       structured_constants;
       exported = _;
     } as input) =
  if !Clflags.dump_rawclambda then (
    Format.fprintf ppf "@.clambda (before Un_anf):@.";
    Printclambda.clambda ppf ulambda;
    Symbol.Map.iter
      (fun sym cst ->
        Format.fprintf ppf "%a:@ %a@." Symbol.print sym
          Printclambda.structured_constant cst)
      structured_constants);
  if !Clflags.dump_cmm then Format.fprintf ppf "@.cmm:@.";
  input

let lambda_to_clambda' ~backend ~prefixname ~ppf_dump (program : Lambda.program)
    =
  let program =
    lambda_to_flambda ~ppf_dump ~prefixname ~backend
      ~size:program.main_module_block_size ~module_ident:program.module_ident
      ~module_initializer:program.code
  in
  let export = Build_export_info.build_transient ~backend program in
  let clambda, preallocated_blocks, constants =
    Profile.record_call "backend" (fun () ->
        (program, export)
        |> Flambda_to_clambda.convert ~ppf_dump
        |> flambda_raw_clambda_dump_if ppf_dump
        |> fun {
                 Flambda_to_clambda.expr;
                 preallocated_blocks;
                 structured_constants;
                 exported;
               } ->
        Compilenv.set_export_info exported;
        let clambda =
          Un_anf.apply ~what:(Compilenv.current_unit_symbol ()) ~ppf_dump expr
        in
        (clambda, preallocated_blocks, structured_constants))
  in
  let constants =
    List.map
      (fun (symbol, definition) ->
        {
          Clambda.symbol = Linkage_name.to_string (Symbol.label symbol);
          exported = true;
          definition;
          provenance = None;
        })
      (Symbol.Map.bindings constants)
  in
  ((clambda, preallocated_blocks, constants), program)

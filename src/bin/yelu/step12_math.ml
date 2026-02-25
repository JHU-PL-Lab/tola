open Langs.Lang_yelu
open Langs.Lang_yelu_utils
open Step_common

let cmd =
  ycmd_of_list
    ([
       ylet "flags" (ytval "tutorial_compiler_flags");
       ylet "math" (ytval "MathFunctions");
       ylet "sqrt" (ytval "SqrtLibrary");
       ylet "check_cxx" (ycstr "check_cxx_source_compiles");
       ylet "inst_libs" (ycstr "installable_libs");
       ylet "have_log" (ycstr "HAVE_LOG");
       ylet "have_exp" (ycstr "HAVE_EXP");
       ylet "use_mymath" (ycstr "USE_MYMATH");
       yc_extern_target "tutorial_compiler_flags";
       yc_include (yfile "MakeTable.cmake");
       yc_add_library ~sources:[ yfile "MathFunctions.cxx" ] (yvar "math");
       yc_target_include_directories (yvar "math")
         [
           ytarget_def ~kind:Interface
             [
               ystr "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>";
               ystr "$<INSTALL_INTERFACE:include>";
             ];
         ];
       yc_option ~value:(ybool true)
         ~msg:"Use tutorial provided math implementation" (yvar "use_mymath");
       yifthen (Ytruthy (yvar "use_mymath"))
         (ycmd_of_list
            ([
               yc_target_compile_definitions (yvar "math")
                 [ ytarget_def ~kind:Private [ yraw "USE_MYMATH" ] ];
               yc_add_library ~type_:Lib_static
                 ~sources:[ yfile "mysqrt.cxx"; yfile "${CMAKE_CURRENT_BINARY_DIR}/Table.h" ]
                 (yvar "sqrt");
               yc_target_include_directories (yvar "sqrt")
                 [
                   ytarget_def ~kind:Private [ ydir "${CMAKE_CURRENT_BINARY_DIR}" ];
                 ];
               yc_set_target_properties (yvar "sqrt")
                 [ ("POSITION_INDEPENDENT_CODE", ystr "${BUILD_SHARED_LIBS}") ];
               yc_target_link_libraries [ yvar "sqrt" ]
                 [ ytarget_def ~kind:Public [ yvar "flags" ] ];
             ]
            @ math_check_cxx_features
            @ [
                yc_target_link_libraries [ yvar "math" ]
                  [ ytarget_def ~kind:Private [ yvar "sqrt" ] ];
                yc_target_compile_definitions (yvar "math")
                  [ ytarget_def ~kind:Private [ yraw "EXPORTING_MYMATH" ] ];
              ]));
       yc_target_link_libraries [ yvar "math" ]
         [ ytarget_def ~kind:Public [ yvar "flags" ] ];
     ]
    @ math_install_libs ~export:(ystr "MathFunctionsTargets") ())

let () = print_cmake cmd

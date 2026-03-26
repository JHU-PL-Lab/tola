```shell
[6/8] cd /home/ex/code/ocaml-build-examples/vendor/z3/build/src/api/ml && /home/ex/.opam/5.3.0/bin/ocamlfind ocamlc -package zarith -I /home/ex/code/ocaml-build-examples/vendor/z3/build/src/api/ml -o /home/ex/code/ocaml-build-examples/vendor/z3/build/src/api/ml/z3.cmi -c /home/ex/code/ocaml-build-examples/vendor/z3/src/api/ml/z3.mli && /home/ex/.opam/5.3.0/bin/ocamlfind ocamlc -package zarith -I /home/ex/code/ocaml-build-examples/vendor/z3/build/src/api/ml -o /home/ex/code/ocaml-build-examples/vendor/z3/build/src/api/ml/z3.cmo -c /home/ex/code/ocaml-build-examples/vendor/z3/src/api/ml/z3.ml && /home/ex/.opam/5.3.0/bin/ocamlfind ocamlopt -package zarith -I /home/ex/code/ocaml-build-examples/vendor/z3/build/src/api/ml -o /home/ex/code/ocaml-build-examples/vendor/z3/build/src/api/ml/z3.cmx -c /home/ex/code/ocaml-build-examples/vendor/z3/src/api/ml/z3.ml
File "/home/ex/code/ocaml-build-examples/vendor/z3/src/api/ml/z3.ml", lines 378-385, characters 6-95:
378 | ......match parameter_kind_of_int (Z3native.get_decl_parameter_kind (gc x) x i) with
379 |       | PARAMETER_INT -> Parameter.P_Int (Z3native.get_decl_int_parameter (gc x) x i)
380 |       | PARAMETER_DOUBLE -> Parameter.P_Dbl (Z3native.get_decl_double_parameter (gc x) x i)
381 |       | PARAMETER_SYMBOL-> Parameter.P_Sym (Z3native.get_decl_symbol_parameter (gc x) x i)
382 |       | PARAMETER_SORT -> Parameter.P_Srt (Z3native.get_decl_sort_parameter (gc x) x i)
383 |       | PARAMETER_AST -> Parameter.P_Ast (Z3native.get_decl_ast_parameter (gc x) x i)
384 |       | PARAMETER_FUNC_DECL -> Parameter.P_Fdl (Z3native.get_decl_func_decl_parameter (gc x) x i)
385 |       | PARAMETER_RATIONAL -> Parameter.P_Rat (Z3native.get_decl_rational_parameter (gc x) x i)
Warning 8 [partial-match]: this pattern-matching is not exhaustive.
Here is an example of a case that is not matched:
(PARAMETER_INTERNAL|PARAMETER_ZSTRING)
File "/home/ex/code/ocaml-build-examples/vendor/z3/src/api/ml/z3.ml", lines 378-385, characters 6-95:
378 | ......match parameter_kind_of_int (Z3native.get_decl_parameter_kind (gc x) x i) with
379 |       | PARAMETER_INT -> Parameter.P_Int (Z3native.get_decl_int_parameter (gc x) x i)
380 |       | PARAMETER_DOUBLE -> Parameter.P_Dbl (Z3native.get_decl_double_parameter (gc x) x i)
381 |       | PARAMETER_SYMBOL-> Parameter.P_Sym (Z3native.get_decl_symbol_parameter (gc x) x i)
382 |       | PARAMETER_SORT -> Parameter.P_Srt (Z3native.get_decl_sort_parameter (gc x) x i)
383 |       | PARAMETER_AST -> Parameter.P_Ast (Z3native.get_decl_ast_parameter (gc x) x i)
384 |       | PARAMETER_FUNC_DECL -> Parameter.P_Fdl (Z3native.get_decl_func_decl_parameter (gc x) x i)
385 |       | PARAMETER_RATIONAL -> Parameter.P_Rat (Z3native.get_decl_rational_parameter (gc x) x i)
Warning 8 [partial-match]: this pattern-matching is not exhaustive.
Here is an example of a case that is not matched:
(PARAMETER_INTERNAL|PARAMETER_ZSTRING)
```
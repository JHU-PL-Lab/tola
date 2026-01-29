open Tola_std

(* path *)
let path_dev = "/home/ex/code/ocaml-build-examples/vendor/z3"
let path_stable = "/home/ex/code/ocaml-build-examples/vendor/z3-stable"

(* input files *)
let lib_so_path root = Fmt.str "%s/build/libz3.so" root
let ocaml_ci root = root $/ ".github/workflows/ocaml.yaml"

(* output files *)
let clang_header_parse header_path json_path =
  Fmt.str "clang -fsyntax-only -Xclang -ast-dump=json -Xclang -I%s %s/z3.h > %s"
    header_path header_path json_path

let out_h_json ver = Fmt.str "_out/z3_h_%s.json" ver

let binding_ocaml_buildgen =
  {|mkdir -p build
cd build
eval $(opam env)
echo "CC: $CC"
echo "CXX: $CXX"
echo "OCAMLFIND: $(which ocamlfind)"
echo "OCAMLC:     $(which ocamlc)"
echo "OCAMLOPT:     $(which ocamlopt)"
echo "OCAML_VERSION: $(ocamlc -version)"
echo "OCAMLLIB: $OCAMLLIB"
cmake .. \
  -N \
  -G Ninja \
  -DZ3_BUILD_LIBZ3_SHARED=ON \
  -DZ3_BUILD_OCAML_BINDINGS=ON \
  -DZ3_BUILD_JAVA_BINDINGS=OFF \
  -DZ3_BUILD_PYTHON_BINDINGS=OFF \
  -DZ3_BUILD_EXECUTABLE=OFF \
  -DZ3_BUILD_TEST_EXECUTABLES=OFF \
  -DCMAKE_VERBOSE_MAKEFILE=TRUE |}

let binding_ocaml_build =
  {|          eval $(opam env)
          cd build
          ninja build_z3_ocaml_bindings |}

(* 
  -Werror=dev \
  --warn-uninitialized \
  
cmake .. \
  -G Ninja \
  -DZ3_BUILD_LIBZ3_SHARED=ON \
  -DZ3_BUILD_OCAML_BINDINGS=ON \
  -DZ3_BUILD_JAVA_BINDINGS=OFF \
  -DZ3_BUILD_PYTHON_BINDINGS=OFF \
  -DZ3_BUILD_EXECUTABLE=OFF \
  -DZ3_BUILD_TEST_EXECUTABLES=OFF \
  -DCMAKE_VERBOSE_MAKEFILE=TRUE
*)

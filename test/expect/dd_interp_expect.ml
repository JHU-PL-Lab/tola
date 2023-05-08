open Interp
module Dd_val = Dd_val.With_closure
open Example

let%expect_test _ =
  Fmt.pr "%a" Dd_val.pp @@ Dd_interp_env.interp Dd_example.e2;
  [%expect {| -7 |}]

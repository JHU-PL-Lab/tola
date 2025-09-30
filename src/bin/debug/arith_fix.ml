open Langs
open Example
open Interp
open Ainterp
module F = Arith.Fixed

let run, table1 = F.mk_memoize Arith_interp.interp
let arun, table2 = F.mk_memoize Arith_ainterp.ainterp

let _ =
  Fmt.pr "\n";
  List.iter
    (fun e ->
      Fmt.(
        pr "@[%a -> %a@]@." Arith.pp e int (run e);
        pr "@[%a => %a@]@." Arith.pp e Just_sign.pp_set (arun e)))
    Arith_example.all;
  F.Table.iter
    (fun k v -> Fmt.(pr "@[%a -> %a@]@." Arith.pp k Just_sign.pp_set v))
    table2;
  Fmt.pr "Table size = %d\n" (F.table_size table1);
  Fmt.pr "Table size = %d\n" (F.table_size table2)

open Base
open Fix

module Make (K : As_key.S) = struct
  module M = Memoize.ForHashedType (K)
  module Table = Glue.HashTablesAsImperativeMaps (K)

  let mk_memoize interp = M.visibly_memoize (M.defensive_fix interp)

  let table_size table =
    let count = ref 0 in
    Table.iter (fun _k _v -> count := !count + 1) table;
    !count
end

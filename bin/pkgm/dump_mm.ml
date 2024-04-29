open Std
module DL_map = Versioned_maps.Multi_alist_map.Make (IntPp) (StringPp)

let dm1 =
  DL_map.(create |> add "a" 1 2 |> add "a" 1 3 |> add "a" 2 4 |> add "d" 3 4)

let () = DL_map.dump Fmt.int dm1

open Base
open Tola_std

module type Multi_alist_map_S = sig
  include Stdlib.Map.S
end

(* D is the directory, K is the key, V is value
   This data structure is to mimic loading paths where
   D is ordered by loading path sequence
   K is not ordered yet
   This data structure is not equiped with versions. It's just a low-level storage.
*)
(* : Multi_alist_map_S with type key = K.t *)
module Make (K : Std.OrderedTypePp) (D : Std.OrderedTypePp) = struct
  module Local_map = Stdlib.Map.Make (K)

  type 'a one_list = (K.t * 'a Local_map.t) list
  type 'a t = (D.t * 'a one_list) list

  let create = []

  let rec add d k v dlm =
    match dlm with
    | (d0, lmap0) :: ds ->
        if D.compare d0 d = 0 then (d0, Local_map.add k v lmap0) :: ds
        else (d0, lmap0) :: add d k v ds
    | [] -> [ (d, Local_map.singleton k v) ]

  let dump pp_v dlm =
    let pp =
      let pp_map = Fmt.Dump.iter_bindings Local_map.iter Fmt.nop K.pp pp_v in
      Fmt.Dump.(list (pair D.pp pp_map))
    in
    Fmt.(vbox @@ pp) Fmt.stdout dlm
end

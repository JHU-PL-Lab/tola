(* open Base *)

module type Versioned_map_S = sig
  include Stdlib.Map.S
end

module Make (K : Stdlib.Map.OrderedType) : Versioned_map_S with type key = K.t =
struct
  include Stdlib.Map.Make (K)
end

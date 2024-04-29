module type Versioned_map_S = sig
  include Map.S
end

module Make (K : Map.OrderedType) : Versioned_map_S with type key = K.t = struct
  include Map.Make (K)
end

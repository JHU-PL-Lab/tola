type t = Id of string [@@deriving eq, ord, ord]

let pp oc (Id x) = Fmt.string oc x

module With_compare = struct
  type nonrec t = t

  let compare = compare
end

module Set = Set.Make (With_compare)
module Map = Map.Make (With_compare)

type t = Id of string [@@deriving eq, ord]

let pp oc (Id x) = Fmt.string oc x

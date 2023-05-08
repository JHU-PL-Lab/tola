type t = Ident of string [@@deriving eq, ord]

let pp oc (Ident x) = Fmt.string oc x

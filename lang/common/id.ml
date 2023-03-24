type t = Ident of string [@@deriving eq]

let pp oc (Ident x) = Fmt.string oc x

module type OrderedTypePp = sig
  include Map.OrderedType

  val pp : t Fmt.t
end

module IntPp = struct
  include Int

  let pp = Fmt.int
end

module StringPp = struct
  include String

  let pp = Fmt.string
end

let pp_std_set set_iter pp_elem oc s =
  Fmt.(vbox @@ iter ~sep:nop set_iter pp_elem) oc s

let pp_std_table table_iter pp_key pp_elem oc s =
  Fmt.(vbox @@ iter_bindings ~sep:nop table_iter (pair pp_key pp_elem)) oc s
(* let pp_dump_std_table ?(name = "set") iter pp_elem oc s =
   let pp_name oc _ = Fmt.string oc name in
   (Fmt.Dump.iter_bindings iter pp_name Fmt.(string ++ cut) pp_elem) oc s *)

module Make_compares (S : sig
  type t

  val compare : t -> t -> Core.Ordering.t
end) =
struct
  open S

  let eq v1 v2 =
    match compare v1 v2 with Less -> false | Equal -> true | Greater -> false

  let lt v1 v2 =
    match compare v1 v2 with Less -> true | Equal -> false | Greater -> false

  let le v1 v2 =
    match compare v1 v2 with Less -> true | Equal -> true | Greater -> false

  let gt v1 v2 =
    match compare v1 v2 with Less -> false | Equal -> false | Greater -> true

  let ge v1 v2 =
    match compare v1 v2 with Less -> false | Equal -> true | Greater -> true
end

module Id = struct
  type t = Id of string [@@deriving eq, ord]

  let str s = Id s
  let pp oc (Id x) = Fmt.string oc x
  let str_of (Id s) = s

  module With_compare = struct
    type nonrec t = t

    let compare = compare
  end

  module Set = struct
    include Set.Make (With_compare)

    let pp = pp_std_set iter pp
  end

  module Map = struct
    include Map.Make (With_compare)

    let pp pp_ele = pp_std_table iter pp pp_ele
    let keys map = map |> to_seq |> Seq.map fst |> Set.of_seq
  end
end

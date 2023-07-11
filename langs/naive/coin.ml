type value = True | False [@@deriving variants, show { with_path = false }]

let name_of_value = Variants_of_value.to_name

type exp =
  | True
  | False
  | Toss
  | And of exp * exp
  | Or of exp * exp
  | Not of exp
[@@deriving variants, show { with_path = false }]

let name_of_exp = Variants_of_exp.to_name
let _not (v : value) : value = match v with True -> False | False -> True

let _and (v1 : value) (v2 : value) : value =
  match (v1, v2) with True, True -> True | _, _ -> False

let _or (v1 : value) (v2 : value) : value =
  match (v1, v2) with False, False -> False | _, _ -> True

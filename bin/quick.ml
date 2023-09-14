(* definition *)
module type S = sig
  type w
end

module type T = sig
  module S_in_T : S
end

module Make_S (S : S) : T with module S_in_T = S = struct
  module S_in_T = S
end

module Make_type_in_S (S : S) : T with type S_in_T.w = S.w = struct
  module S_in_T = S
end

module Make_S_and_type_in_S (S : S) : T with module S_in_T = S = struct
  module S_in_T = S
end

module Make_St (S : S) : T with module S_in_T = S = struct
  module S_in_T = S
end

module Make_type_in_St (S : S) : T with type S_in_T.w = S.w = struct
  module S_in_T = S
end

module Make_S_and_type_in_St (S : S) : T with module S_in_T = S = struct
  module S_in_T = S
end

(* use *)

module S_int : S = struct
  type w = int
end

module Make_use_T (T : T) = struct
  type t = T.S_in_T.w
end

module Make_use_int_T (T : T with type S_in_T.w = int) = struct
  type t = int

  let a : int = 1
end

module Make_use_int_in_S_in_T (T : T with module S_in_T = S_int) = struct
  type t = int

  let a : int = 1
end

module T1 = Make_S (S_int)
module T2 = Make_type_in_S (S_int)
module T3 = Make_S_and_type_in_S (S_int)
module U1 = Make_use_T (T1)
module U2 = Make_use_T (T2)
module U3 = Make_use_T (T3)
module W1 = Make_use_int_T (T1)
module W2 = Make_use_int_T (T2)
module W3 = Make_use_int_T (T3)
module D1 = Make_use_int_in_S_in_T (T1)
module D2 = Make_use_int_in_S_in_T (T2)
module D3 = Make_use_int_in_S_in_T (T3)

(* module SS1 : T with type S_in_T.w = int = Make_S (S_int) *)
(* module SS2 : T with type S_in_T.w = int = Make_type_in_S (S_int) *)
(* module SS3 : T with type S_in_T.w = int = Make_S_and_type_in_S (S_int) *)

(* module SS1 : T with module S_in_T = S_int = Make_S (S_int)
   module SS2 : T with module S_in_T = S_int = Make_type_in_S (S_int)
   module SS3 : T with module S_in_T = S_int = Make_S_and_type_in_S (S_int) *)

(* module SS1 : T with module S_in_T = S_int and type S_in_T.w = int =
     Make_S (S_int)

   module SS2 : T with module S_in_T = S_int and type S_in_T.w = int =
     Make_type_in_S (S_int)

   module SS3 : T with module S_in_T = S_int and type S_in_T.w = int =
     Make_S_and_type_in_S (S_int) *)

open Std

(* Ordering seems to be a module *)

module type S = sig
  type t
  type ordering

  val compare : t -> t -> ordering
  val of_str : string -> t
  val to_str : t -> string
end

module type S_tot = sig
  type t
  type ordering = Std.Ordering.t

  val compare : t -> t -> ordering
  val of_str : string -> t
  val to_str : t -> string
end

(* module type Sp = sig
     type t

     val compare : t -> t -> PartialOrdering.t
     val of_str : string -> t
     val to_str : t -> string
   end *)

module Partial_ordering = struct
  type t = int * int

  let compare t1 t2 =
    let open PartialOrdering in
    let t11, t12 = t1 in
    let t21, t22 = t2 in
    if t11 > t21 && t12 > t22 then Greater
    else if t11 = t21 && t12 = t22 then Equal
    else if t11 < t21 && t12 < t22 then Less
    else Unknown

  let of_str s = Scanf.sscanf s "%d %d" (fun x1 x2 -> (x1, x2))
  let to_str (x1, x2) = Printf.sprintf "%d %d" x1 x2
end

(* This can be used to implemented a hash-table for multi-part versioing key.
   But it's not used to model a versioning string.
*)
module Naive_radix = struct
  type t =
    | Root
    | Int_layer of (int * t) list
    | String_layer of (string * t) list

  type case = K_int | K_string
  type key1 = K_int of int | K_string of string
  type key = key1 list

  let root = Root

  let add_to_layer key1 tree =
    match (key1, tree) with
    | K_int x, Root -> Int_layer [ (x, Root) ]
    | K_string x, Root -> String_layer [ (x, Root) ]
    | K_int x, Int_layer xs -> Int_layer ((x, Root) :: xs)
    | K_string x, String_layer xs -> String_layer ((x, Root) :: xs)
    | _ -> failwith "case mismatch"

  let rec map f key tree =
    match (key, tree) with
    | [], _ -> f tree
    | K_int x :: key', Int_layer xs ->
        let tree' = List.assoc x xs in
        map f key' tree'
    | K_string x :: key', String_layer xs ->
        let tree' = List.assoc x xs in
        map f key' tree'
    | _ -> failwith "case mismatch"

  let find = map (fun x -> x)

  let rec subst key tree t2 =
    match (key, tree) with
    | [], _ -> t2
    | K_int x :: key', Int_layer xs ->
        Int_layer
          (List.map
             (fun (ki, ti) ->
               let ti' = if ki = x then subst key' ti t2 else ti in
               (ki, ti'))
             xs)
    | K_string x :: key', String_layer xs ->
        String_layer
          (List.map
             (fun (ki, ti) ->
               let ti' = if ki = x then subst key' ti t2 else ti in
               (ki, ti'))
             xs)
    | _ -> failwith "case mismatch"

  let add_to_string_layer x = function
    | Root -> String_layer [ (x, Root) ]
    | String_layer xs -> String_layer ((x, Root) :: xs)
    | _ -> failwith "not string"

  let add_to_int_layer x = function
    | Root -> Int_layer [ (x, Root) ]
    | Int_layer xs -> Int_layer ((x, Root) :: xs)
    | _ -> failwith "not int"

  let rec pp fmt tree =
    match tree with
    | Root -> Fmt.string fmt "."
    | String_layer xs ->
        let pp_ele fmt (x, tree) =
          Fmt.string fmt x;
          Fmt.pf fmt "@[<h 2>%a@]" pp tree
        in
        Fmt.Dump.list pp_ele fmt xs
    | Int_layer xs ->
        let pp_ele fmt (x, tree) =
          Fmt.int fmt x;
          Fmt.pf fmt "@[<h 2>%a@]" pp tree
        in
        Fmt.Dump.list pp_ele fmt xs

  let pp = Fmt.hbox pp
end

(*  *)
(* module Multi_part = struct
     type 'a tree = N_root | N_child of (edge * 'a tree) list
     and edge = string

     type _ radix =
       | Leaf : _ radix
       | Next : ('part * string * _ radix) list -> 'part radix

     let root = Leaf

     let add_next x s = function
       | Leaf -> Next [ (x, s, Leaf) ]
       | Next xs -> Next ((x, s, Leaf) :: xs)

     (*
        r - 1
          \
            2
     *)

     let rec pp : type t. Format.formatter -> t radix -> unit =
      fun fmter radix ->
       match radix with
       | Leaf -> Fmt.string fmter "l"
       | Next xs ->
           let pp_entry fmter (_, s, r) =
             Fmt.string fmter s;
             pp fmter r
           in
           Fmt.Dump.list pp_entry fmter xs
   end *)

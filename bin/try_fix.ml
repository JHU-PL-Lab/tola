open Fix

module Int_prop = struct
  type property = int

  let bottom = 0
  let equal = Int.equal
  let is_maximal _ = false
end

module F =
  Fix.ForType
    (struct
      type t = int
    end)
    (Int_prop)

let mk_sum x sum = if x = 0 then 0 else x + sum (x - 1)
let sum = F.lfp mk_sum

let () =
  Fmt.pr "@.%d\n" (sum 3);
  Fmt.pr "%d\n" (sum 10)

module Int_set = Set.Make (struct
  type t = int

  let compare = Int.compare
end)

module Int_set_prop = Prop.Set (Int_set)

module F2 =
  Fix.ForType
    (struct
      type t = int
    end)
    (Int_set_prop)

let basic = Int_set.(empty |> add 0 |> add 1)
let pp_int_list = Fmt.Dump.list Fmt.int

let pp_set fmt set =
  let elems = set |> Int_set.to_seq |> List.of_seq in
  pp_int_list fmt elems

let mk_sum_2 (x : int) (sum : int -> Int_set.t) : Int_set.t =
  if x = 0 then basic else Int_set.map (fun t -> t + 1) (sum (x - 1))

let sum_2 = F2.lfp mk_sum_2

let () =
  Fmt.pr "@.%a\n" pp_set (sum_2 3);
  Fmt.pr "%a\n" pp_set (sum_2 10)

type int_set_list = Int_set.t list

module Int_set_list_prop = struct
  type property = int_set_list

  let bottom = []
  let equal = List.equal Int_set.equal
  let is_maximal _ = false
end

let pp_int_set_list = Fmt.Dump.list pp_set

module Int_list_prop = struct
  type property = int list

  let bottom = []
  let equal = List.equal Int.equal
  let is_maximal _ = false
end

(* F3 doesn't have a recursive type on `t`, so we need to manual construct the `t` runtime to satisfy the fix *)
module F3 =
  Fix.ForType
    (struct
      type t = int list
    end)
    (Int_list_prop)

let rec mk_sum_3 (xs : int list) (sum : int list -> int list) : int list =
  match xs with x :: xs -> real_sum x :: sum xs | [] -> []

and real_sum x = if x = 0 then 0 else x + real_sum (x - 1)

let sum_3 = F3.lfp mk_sum_3

let () =
  Fmt.pr "@.%a\n" pp_int_list (sum_3 []);
  Fmt.pr "%a\n" pp_int_list (sum_3 [ 1 ]);
  Fmt.pr "%a\n" pp_int_list (sum_3 [ 1; 2; 10 ])

let mk_sum_4 (xs : int list) (sum : int list -> int list) : int list =
  match xs with
  | x :: xs -> (
      if x = 0 then 0 :: sum xs
      else
        let vs = sum ((x - 1) :: xs) in
        match vs with v :: vs -> (x + v) :: vs | [] -> failwith "why")
  | [] -> []

let sum_4 = F3.lfp mk_sum_4

let () =
  Fmt.pr "@.%a\n" pp_int_list (sum_4 []);
  Fmt.pr "%a\n" pp_int_list (sum_4 [ 1 ]);
  Fmt.pr "%a\n" pp_int_list (sum_4 [ 1; 2; 10 ])

let rec mk_sum_5 (xs : int list) (sum : int list -> int list) : int list =
  match xs with x :: xs -> mk_sum_one x xs sum | [] -> []

and mk_sum_one x xs sum =
  if x = 0 then 0 :: sum xs
  else
    let vs = sum ((x - 1) :: xs) in
    match vs with v :: vs -> (x + v) :: vs | [] -> failwith "why"

let sum_5 = F3.lfp mk_sum_5

let () =
  Fmt.pr "@.%a\n" pp_int_list (sum_5 []);
  Fmt.pr "%a\n" pp_int_list (sum_5 [ 1 ]);
  Fmt.pr "%a\n" pp_int_list (sum_5 [ 1; 2; 10 ])

module F6 =
  Fix.ForType
    (struct
      type t = int list
    end)
    (Int_set_list_prop)

let rec mk_sum_6 (xs : int list) (sum : int list -> int_set_list) : int_set_list
    =
  match xs with x :: xs -> mk_sum_one x xs sum | [] -> []

and mk_sum_one x xs sum =
  if x = 0 then basic :: sum xs
  else
    let vs = sum ((x - 1) :: xs) in
    match vs with
    | v :: vs -> Int_set.map (fun t -> t + x) v :: vs
    | [] -> failwith "why"

let sum_6 = F6.lfp mk_sum_6

let () =
  Fmt.pr "@.%a\n" pp_int_set_list (sum_6 []);
  Fmt.pr "%a\n" pp_int_set_list (sum_6 [ 1 ]);
  Fmt.pr "%a\n" pp_int_set_list (sum_6 [ 1; 2; 10 ])

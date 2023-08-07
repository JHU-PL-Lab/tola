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
  Fmt.pr "%d\n" (sum 3);
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

let pp_set fmt set =
  let elems = set |> Int_set.to_seq |> List.of_seq in
  (Fmt.Dump.list Fmt.int) fmt elems

let mk_sum_2 (x : int) (sum : int -> Int_set.t) : Int_set.t =
  if x = 0 then basic else Int_set.map (fun t -> t + 1) (sum (x - 1))

let sum_2 = F2.lfp mk_sum_2

let () =
  Fmt.pr "%a\n" pp_set (sum_2 3);
  Fmt.pr "%a\n" pp_set (sum_2 10)

module F3 =
  Fix.ForType
    (struct
      type t = int list
    end)
    (Int_set_prop)

(* let rec mk_sum_3 (xs : int list) (sum : int -> Int_set.t) : Int_set.t =
      if x = 0 then basic else Int_set.map (fun t -> t + 1) (sum (x - 1)) *)

let rec f x =
  if x > 0 then
    f (x - 1)
  else
    2 + 3
  [@@inline]

let a = f 0 - 1

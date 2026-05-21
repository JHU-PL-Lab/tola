type result = { value : int; doubled : int }

let sum_doubled a b =
  let v = Tiny.sum a b in
  { value = v; doubled = v * 2 }

let diff_doubled a b =
  let v = Tiny.diff a b in
  { value = v; doubled = v * 2 }

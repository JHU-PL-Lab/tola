open Lang
open Coin

let tt = True
let ff = False
let tos = Toss
let t2 = And (Toss, Toss)
let t1t = And (Toss, False)
let t2o = Or (Toss, Toss)
let t1to = Or (Toss, True)
let nt = Not True
let nto = Not Toss

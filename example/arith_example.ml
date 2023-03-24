open Lang.Arith

let n0 = Int 0
let n3 = Int 3
let n4 = Int 4
let ne3 = Int (-3)
let ne4 = Int (-4)
let i = Input
let e1 = Plus (n3, n4)
let e2 = Plus (ne3, ne4)
let e3 = If0 (n0, n3, n4)
let e4 = If0 (n0, n3, ne3)
let e5 = If0 (i, If0 (i, n3, n0), ne3)
let e6 = If0 (i, n4, ne4)
let all = [ e1; e2; e3; e4; e5; e6 ]

# recursion

```ocaml
T(k,x) = Var (i)  |  for i = 0..x
       | Lam (x+1, T(k-1,x)) 
       | App (T(k-1,x), T(k-1,x)) |
       | ...
```

if T(k) means exactly height k,
    then case App should cover non-exact cases
    just use one form may have missing terms
if T(k) means at-most at height k,
    then the result may contain duplicate cases

let's tentatively treat T(k,0) means exactly at height k.

where `k` is the height and `x` is bound var index

# open and close


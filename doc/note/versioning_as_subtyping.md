## Here is a previous example which haven't thought on both nominal and structural subtyping

- 1: a package `foo_1_0_impl` implements a versioned interface `foo_1_0_sig`, saying as `foo_1_0_impl : foo_1_0_sig`. The same for `foo_1_1_impl : foo_1_1_sig`

2. subtyping solely on version scheme `foo_1_0_sig <: foo_1_1_sig`

```ocaml
let pkg_std_1_0 : vtype<std, 1.0> && dep<{}> = std_1_0_impl in
let pkg_std_1_1 : vtype<std, 1.1> && dep<{}> = std_1_1_impl in
let pkg_foo_1.0 : vtype<foo, 1.0> && dep<{std>=1.0}> = foo_1_0_impl in
let pkg_foo_1.1 : vtype<foo, 1.1> && dep<{std>=1.0}> = foo_1_1_impl in

let try_resolve pkg

let resolve_case1 = try_resolve pkg_foo_1.0 {pkg_std_1_0} in
let resolve_case2 = try_resolve pkg_foo_1.1 {pkg_std_1_0} in
```

- Have you used an AI tool to generate pictures?  Now they mainly use a diffusion model, which generates the picture from pure noise gradually. Now I think it's a metaphor of research ideas
  - I am thinking about the motivation for why I said two languages with two interpreters.
  - 1. A system running itself is a running interpreter where we make a slight abstraction over files to have `Project`, `Package`, `Binary`. Expressions/actions of this language are tool actions e.g. compile, pkg-install, resolve. This language is mainly for a universal abstract across tools.
  - 2. Versioning is like abstract types with type coercion or subtyping. A concrete pkg at a version has a

(** Binding language vocabulary. Tiny file by design so that
    [Canary_basic] and [Canary_store] can both depend on it without
    creating a circular dependency between themselves. Lifted from
    [surface/canary_artifact_api] on 2026-06-01 to eliminate the
    latent layer reversal where [base/] depended on [surface/]. *)

type lang =
  | Cpp
  | OCaml
  | Python
  | Rust
  | CSharp
  | Java
[@@deriving show]

let string_of_lang = function
  | Cpp -> "cpp" | OCaml -> "ocaml"
  | Python -> "python" | Rust -> "rust" | CSharp -> "csharp" | Java -> "java"

let display_of_lang = function
  | Cpp -> "C++" | OCaml -> "OCaml"
  | Python -> "Python" | Rust -> "Rust" | CSharp -> "C#" | Java -> "Java"

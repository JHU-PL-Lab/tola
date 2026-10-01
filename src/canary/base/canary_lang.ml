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
[@@deriving show, eq]

let string_of_lang = function
  | Cpp -> "cpp" | OCaml -> "ocaml"
  | Python -> "python" | Rust -> "rust" | CSharp -> "csharp" | Java -> "java"

let display_of_lang = function
  | Cpp -> "C++" | OCaml -> "OCaml"
  | Python -> "Python" | Rust -> "Rust" | CSharp -> "C#" | Java -> "Java"

(** Every language, in the type's order. *)
let all : lang list = [ Cpp; OCaml; Python; Rust; CSharp; Java ]

(* a new language fails this match first, here beside [all] *)
let _all_is_every_lang : lang -> unit = function
  | Cpp | OCaml | Python | Rust | CSharp | Java -> ()

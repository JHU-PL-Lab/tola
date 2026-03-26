open Base

(* ── Package managers and locations ──
   A store is any place artifacts can be fetched from or published to.
   Location identifies where an artifact physically resides. *)

type package_manager = Apt | Brew | Opam | Unsupported

type location = Build_tree | System_pm | Lang_pm | Wild of string

let string_of_pm = function
  | Apt -> "apt"
  | Brew -> "brew"
  | Opam -> "opam"
  | Unsupported -> "unsupported"

let string_of_location = function
  | Build_tree -> "build tree"
  | System_pm -> "system PM"
  | Lang_pm -> "lang PM"
  | Wild s -> s

let is_source_location = function
  | Build_tree -> true
  | System_pm | Lang_pm | Wild _ -> false

(* Abstract unified store for action rule enumeration *)
let store = Wild "store"

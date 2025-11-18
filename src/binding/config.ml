open Base
open Tola_std

type inspect_config = {
  os : OpamStd.Sys.os;
  (* TODO: very hacky for ocaml *)
  so_as_dylib : bool;
  check_search_path : bool;
}

let default_inspect_config =
  { os = Std.the_os; so_as_dylib = false; check_search_path = true }

let ocamlmklib_inspect_config =
  { default_inspect_config with so_as_dylib = Std.is_macos }

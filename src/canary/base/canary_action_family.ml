(** THE ACTION FAMILY (2026-09-23, status.md §2.7 phase B2) — an action
    with its language erased.

    [Canary_basic.action] is per language, and so is every step:
    [Probe_binding OCaml]. The overview's layered graph is not. Its [run]
    edge is realized by probing a binding in whatever language the
    binding is written, so naming the action on that edge needs a word
    for "probe_binding, any language", and base had none. The edges
    carried a string that nothing checked against the catalogue.

    The names are PLACEHOLDERS (user, 2026-09-23: "we can later decide the
    concrete names, and for now you can pick new easy ones"). Each is the
    action's own name with its language dropped, so [of_action] reads as
    a projection and a later rename touches this file alone. *)

open Base

type t =
  | Configure
  | Scan_sources
  | Build_headers
  | Build_lib
  | Install_lib
  | Build_binding
  | Build_app
  | Fetch_source
  | Fetch_headers
  | Fetch_lib
  | Fetch_binding
  | Fetch_binding_source
  | Fetch_app
  | Pack_source
  | Pack_headers
  | Pack_lib
  | Pack_binding
  | Pack_binding_source
  | Pack_app
  | Probe_lib
  | Probe_binding
  | Probe_app

(** Total over [Canary_basic.action]: the compiler holds this match to
    every constructor, so an action cannot land without a family. *)
let of_action : Canary_basic.action -> t = function
  | Canary_basic.Configure -> Configure
  | Canary_basic.Scan_sources -> Scan_sources
  | Canary_basic.Build_headers -> Build_headers
  | Canary_basic.Build_lib -> Build_lib
  | Canary_basic.Install_lib -> Install_lib
  | Canary_basic.Build_binding _ -> Build_binding
  | Canary_basic.Build_app _ -> Build_app
  | Canary_basic.Fetch Canary_basic.Source -> Fetch_source
  | Canary_basic.Fetch Canary_basic.Headers -> Fetch_headers
  | Canary_basic.Fetch Canary_basic.Lib -> Fetch_lib
  | Canary_basic.Fetch (Canary_basic.Binding _) -> Fetch_binding
  | Canary_basic.Fetch (Canary_basic.Binding_source _) -> Fetch_binding_source
  | Canary_basic.Fetch Canary_basic.App -> Fetch_app
  | Canary_basic.Publish Canary_basic.Source -> Pack_source
  | Canary_basic.Publish Canary_basic.Headers -> Pack_headers
  | Canary_basic.Publish Canary_basic.Lib -> Pack_lib
  | Canary_basic.Publish (Canary_basic.Binding _) -> Pack_binding
  | Canary_basic.Publish (Canary_basic.Binding_source _) -> Pack_binding_source
  | Canary_basic.Publish Canary_basic.App -> Pack_app
  | Canary_basic.Probe_lib -> Probe_lib
  | Canary_basic.Probe_binding _ -> Probe_binding
  | Canary_basic.Probe_app _ -> Probe_app

(** The action's own spelling ({!Canary_basic.string_of_action}) with the
    language suffix dropped — pinned against it, so the two cannot come
    to spell one action two ways. *)
let to_string : t -> string = function
  | Configure -> "configure"
  | Scan_sources -> "scan_sources"
  | Build_headers -> "build_headers"
  | Build_lib -> "build_lib"
  | Install_lib -> "install_lib"
  | Build_binding -> "build_binding"
  | Build_app -> "build_app"
  | Fetch_source -> "fetch_source"
  | Fetch_headers -> "fetch_headers"
  | Fetch_lib -> "fetch_lib"
  | Fetch_binding -> "fetch_binding"
  | Fetch_binding_source -> "fetch_binding_source"
  | Fetch_app -> "fetch_app"
  | Pack_source -> "pack_source"
  | Pack_headers -> "pack_headers"
  | Pack_lib -> "pack_lib"
  | Pack_binding -> "pack_binding"
  | Pack_binding_source -> "pack_binding_source"
  | Pack_app -> "pack_app"
  | Probe_lib -> "probe_lib"
  | Probe_binding -> "probe_binding"
  | Probe_app -> "probe_app"

let equal (a : t) (b : t) : bool = Poly.equal a b

(** The families the action CATALOGUE ranges over, in catalogue order —
    every one some store can run ({!Canary_basic.store_actions}). *)
let of_catalogue () : t list =
  Canary_basic.store_actions ~langs:Canary_lang.[ OCaml; Python ]
  |> List.map ~f:of_action
  |> List.fold ~init:[] ~f:(fun acc f ->
         if List.mem acc f ~equal then acc else acc @ [ f ])

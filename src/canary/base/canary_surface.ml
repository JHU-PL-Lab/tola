(** [Canary_surface] — the checking-points surface, split out of
    {!Canary_artifact} (project-definition redesign, seam S1 —
    [doc/canary/design/ssot.md] §6.1).

    [Canary_artifact.t] conflated two concerns: {b provenance}
    (components / headers / binding source_dir — where artifacts live)
    and {b checking points} (watchlists + expected symbols/soname/abi —
    what detection inspects). This module is the checking half. The
    provenance half moves to the store side.

    Lives in a sibling module rather than inside [Canary_artifact]
    because [native_surface] would otherwise shadow the identically-named
    record labels on [native_api] within one module. It sits below
    [Canary_step_builder] so [runner_spec] can reference [surface]
    without a cycle. *)

open Base

type native_surface = {
  symbol_prefixes : string list;
  stable_symbols : string list; (* L1a: must be exported *)
  versioned_symbols : string list; (* L1b *)
  soname : string option; (* L4 *)
  c_runtime : string option;
  cxx_abi : string option;
}

type binding_surface = {
  module_watchlist : string list; (* L3 *)
  type_watchlist : string list; (* L2 *)
}

type surface = {
  native : native_surface;
  bindings : (Canary_lang.lang * binding_surface) list;
}

let empty_native_surface =
  {
    symbol_prefixes = [];
    stable_symbols = [];
    versioned_symbols = [];
    soname = None;
    c_runtime = None;
    cxx_abi = None;
  }

let empty_surface = { native = empty_native_surface; bindings = [] }

(** Extract the checking-half from an [api_source]. The provenance half
    ([components] / [headers] / [source_dir]) is dropped — it belongs to
    the store. This is the migration path for projects that still carry
    an [api_source] (z3 / llvm / tiny). *)
let surface_of_api (api : Canary_artifact.t) : surface =
  let na : Canary_artifact.native_api = api.native_api in
  {
    native =
      {
        symbol_prefixes = na.symbol_prefixes;
        stable_symbols = na.stable_symbols;
        versioned_symbols = na.versioned_symbols;
        soname = na.soname;
        c_runtime = na.c_runtime;
        cxx_abi = na.cxx_abi;
      };
    bindings =
      List.map api.binding_apis ~f:(fun (b : Canary_artifact.binding_api) ->
          ( b.lang,
            {
              module_watchlist = b.module_watchlist;
              type_watchlist = b.type_watchlist;
            } ));
  }

let native_watchlist (s : surface) = s.native.stable_symbols

let binding_watchlist_exn (s : surface) (lang : Canary_lang.lang) =
  match List.find s.bindings ~f:(fun (l, _) -> Poly.equal l lang) with
  | Some (_, b) -> b.module_watchlist
  | None ->
      failwith
        [%string
          "canary_surface: no binding surface for lang \
           %{Canary_lang.show_lang lang}"]

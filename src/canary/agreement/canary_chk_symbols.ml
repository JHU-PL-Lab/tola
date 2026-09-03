(** Symbol agreements — what the consumer requires, what the provider exports

    One module per check family (design: the per-check module pattern).
    Each check states its CATEGORY (descriptive), its STANDING, and a
    falsifier-phrased sentence; the function keeps whatever signature
    suits it, and the caller supplies the inputs. *)

open Base
open Canary_agreement
module Cat = Canary_agreement

let cat = Cat.Symbols `Required
let standing = Cat.Declared
let says = "every symbol the binding's stub references is exported by the lib"

type compat_result =
  | Compatible
  | Compatible_lag of { required : int; provided : int }
      (** inclusion holds, but the consumer's required set covers only a
          small fraction of the provider's surface — the POSSIBLY
          OUT-OF-DATE signal (2026-08-17, user): set-inclusion alone
          can't tell wrapping-a-subset (by design) from a stale binding
          (by accident), so this is a WARNING, never a failure. *)
  | Missing of { symbols : string list }
  | Unknown   (* one side lacks the data needed to decide *)

(** [c1 cmp_symbol] implementation. Set-inclusion check: every C symbol the
    consumer requires must be defined by the provider.

    {!check_c_compat} takes:
    - [binding_stub]: consumer-side undefined refs, from one of
      {ul
        {- {i bo7 compiled_binding_ocaml.stub-a} via
           [inspect_binding.py --kind stub] on [libtiny_stubs.a], or}
        {- {i bpe3 compiled_binding_cext.so} via [nm -u] on the cext [.so]
           reshaped to [c_stub] form (run.sh handles the coercion).}
      }
    - [native_lib]: provider-side defined symbols, from {i n4 lib_native.so}
      via [inspect_native.py] on the [.so].

    Returns:
    - [Compatible] — every required symbol present.
    - [Missing { symbols }] — at least one required symbol absent.
    - [Unknown] — one side has no symbol data (treat as inconclusive). *)
let check_c_compat ~(binding_stub : stub_inspect) ~(native_lib : native_inspect)
    : compat_result =
  if List.is_empty binding_stub.requires then Unknown
  else if List.is_empty native_lib.symbols then Unknown
  else
    let provided = Set.of_list (module String) native_lib.symbols in
    let missing = List.filter binding_stub.requires
        ~f:(fun s -> not (Set.mem provided s)) in
    if List.is_empty missing then
      (* the coverage note: a consumer covering < 10% of the provider's
         surface passes inclusion but may be OUT-OF-DATE — the warning
         the result carries (by design or by accident; can't tell). *)
      let required = List.length binding_stub.requires in
      let provided_n = List.length native_lib.symbols in
      if required * 10 < provided_n then
        Compatible_lag { required; provided = provided_n }
      else Compatible
    else Missing { symbols = missing }

(** The lag's CONCRETE witnesses (2026-08-17, user): one required symbol
    (the consumer's surface — IN) and one provided-but-unrequired symbol
    (the rest of the provider — OUT), so the warning can show "some are
    in and some are out" instead of bare counts. [None] = can't pick
    (the inclusion already holds, so the IN pick always exists; the OUT
    pick needs at least one unused symbol). *)
let lag_examples ~(binding_stub : stub_inspect) ~(native_lib : native_inspect)
    : (string * string) option =
  match binding_stub.requires with
  | [] -> None
  | in_example :: _ ->
      let required_set = Set.of_list (module String) binding_stub.requires in
      List.find_map native_lib.symbols ~f:(fun s ->
          if Set.mem required_set s then None else Some (in_example, s))

(** The c1 input pair: the existing C_stub + Native_lib summaries among
    [inputs], loaded. [None] = either side missing (the check can't
    decide — [c1_predict]/[c1_lag_note] both report nothing). *)
let c1_pair ~resolve (inputs : inspect_input list) :
    (stub_inspect * native_inspect) option =
  let stub_path =
    List.find_map inputs
      ~f:(function C_stub ps -> pick_existing ~resolve ps | _ -> None)
  in
  let lib_path =
    List.find_map inputs
      ~f:(function Native_lib ps -> pick_existing ~resolve ps | _ -> None)
  in
  match stub_path, lib_path with
  | Some s, Some l -> Some (load_stub s, load_native l)
  | _ -> None

(** c1 cmp_symbol (L0). Pairs C_stub + Native_lib paths and returns
    the missing C symbols from {!check_c_compat}. *)

let c1_predict ~resolve (inputs : inspect_input list) : string list =
  match c1_pair ~resolve inputs with
  | Some (stub, lib) -> (
      match check_c_compat ~binding_stub:stub ~native_lib:lib with
      | Missing { symbols } -> symbols
      | Compatible | Compatible_lag _ | Unknown -> [])
  | None -> []

(** The c1 coverage NOTE (2026-08-17, user): when the check passes but
    the consumer's required set covers a small fraction of the
    provider's surface, warn POSSIBLY OUT-OF-DATE — inclusion alone
    can't tell wrapping-a-subset (by design) from a stale binding (by
    accident). A WARNING, never a failure: [None] when the data is
    missing or the coverage is healthy. Logged by the runner as a
    [compat_note] event. *)

let c1_lag_note ~resolve (inputs : inspect_input list) : string option =
  match c1_pair ~resolve inputs with
  | Some (stub, lib) -> (
      match check_c_compat ~binding_stub:stub ~native_lib:lib with
      | Compatible_lag { required; provided } ->
          let witness =
            match lag_examples ~binding_stub:stub ~native_lib:lib with
            | Some (in_use, unused) ->
                Printf.sprintf " (e.g. %s in use; %s in the unused remainder)"
                  in_use unused
            | None -> ""
          in
          Some
            (Printf.sprintf
               "c1 cmp_symbol: consumer requires %d of the provider's %d \
                symbols%s — POSSIBLY OUT-OF-DATE (a small consumer surface may \
                be by design or lag)"
               required provided witness)
      | Compatible | Missing _ | Unknown -> None)
  | None -> None

(** c2 cmp_api_completeness (L3). Reads watchlist_missing from
    Ocaml_mli / Python_attrs JSONs and expands each missing name into
    its observable variants (e.g. [Llvm.Opcode.UncondBr] →
    [Opcode.UncondBr], [UncondBr]). *)

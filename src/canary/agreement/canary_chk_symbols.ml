(** Symbol agreements — what the consumer requires, what the provider exports

    One module per check family (design: the per-check module pattern).
    Each check states its CATEGORY (descriptive), its STANDING, and a
    falsifier-phrased sentence; the function keeps whatever signature
    suits it, and the caller supplies the inputs. *)

open Base
open Canary_agreement
module Cat = Canary_check_cat

let cat = Cat.Symbols `Required
let standing = Cat.Declared
let says = "every symbol the binding's stub references is exported by the lib"

(** The c1 input pair: the existing C_stub + Native_lib summaries among
    [inputs], loaded. [None] = either side missing (the check can't
    decide — [c1_predict]/[c1_lag_note] both report nothing). *)
let c1_pair ~resolve (inputs : inspect_input list) :
    (stub_inspect * native_inspect) option =
  let stub_path =
    List.find_map inputs
      ~f:(function C_stub ps -> Canary_evidence.pick_existing ~resolve ps | _ -> None)
  in
  let lib_path =
    List.find_map inputs
      ~f:(function Native_lib ps -> Canary_evidence.pick_existing ~resolve ps | _ -> None)
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

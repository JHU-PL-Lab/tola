(** Type agreements — the C signatures at the header/stub boundary

    One module per check family (design: the per-check module pattern).
    Each check states its CATEGORY (descriptive), its STANDING, and a
    falsifier-phrased sentence; the function keeps whatever signature
    suits it, and the caller supplies the inputs. *)

open Base
open Canary_agreement
module Cat = Canary_check_cat

let cat = Cat.Types `Signature
let standing = Cat.Declared
let says = "the types a stub declares agree with the header it wraps"

let c6_predict ~resolve (inputs : inspect_input list) : string list =
  let header_path =
    List.find_map inputs
      ~f:(function Typed_header ps -> Canary_agreement_run.pick_existing ~resolve ps | _ -> None) in
  let stub_path =
    List.find_map inputs
      ~f:(function Typed_binding_stub ps -> Canary_agreement_run.pick_existing ~resolve ps
                 | _ -> None) in
  match header_path, stub_path with
  | Some hp, Some sp ->
      let h = Canary_agreement.load_typed_signatures hp in
      let s = Canary_agreement.load_typed_signatures sp in
      List.filter_map h.functions ~f:(fun (name, h_sig) ->
        match List.Assoc.find s.functions name ~equal:String.equal with
        | None -> None
        | Some s_sig ->
            if String.equal h_sig.return_type s_sig.return_type
               && List.equal String.equal h_sig.arg_types s_sig.arg_types
            then None
            else Some name)
  | _ -> []

(* Best-effort: ".ok" marker file alongside cmd success implies probe step
   succeeded. probe.log non-empty + no .ok marker implies cmd failed (which
   for Expect_failure cases is the GOAL — see step_expectation in
   canary_action.ml). We're not re-implementing the runner's verdict; just
   distinguishing "log has compile error text" from "log shows runtime ok". *)

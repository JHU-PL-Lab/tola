(** [Canary_compat_run] — drives the surface-theory compat contract over
    the action graph's cached artifacts (surface/, next to the contract).

    Companion to {!Canary_compat}: that module is the pure theory (types
    and c1..c8 comparators); this module locates the cached inspector
    JSONs in [_out/canary/projects/<project>/<step>/], hands them to the
    pure comparators, and derives the expected failure substrings the
    [Expect_compat_failure] runner consumes. What lives here:

    - [typed_input] — the action-graph's view of which JSONs a step
      expectation should consume (constructors map to surface roles).
    - [predicted_contains_any] / [predicted_contains_any_v2] — derive
      expected probe-failure substrings from cached inspector JSONs;
      consumed by {!Canary_action}'s [Expect_compat_failure] runner.
    - Cached-summary path resolution: [resolve_variant],
      [find_lib_inspect], [find_stub_inspect], [find_mli_inspect],
      [find_python_inspect].
    - CLI entry points: [run] (single stub/lib pair),
      [run_for_project], [verify_for_project].
    - Reporting: [print_result]. *)

open Base
open Canary_compat


(* ── Reporting ── *)

let print_result ~(stub : stub_inspect) ~(lib : native_inspect) result =
  Fmt.pr "stub:     %s (%d required symbols)@."
    stub.path (List.length stub.requires);
  Fmt.pr "lib:      %s (%d defined symbols)@.@."
    lib.path (List.length lib.symbols);
  match result with
  | Compatible ->
      Fmt.pr "PREDICTION: COMPATIBLE — every required symbol is provided.@."
  | Missing { symbols } ->
      Fmt.pr "PREDICTION: INCOMPATIBLE — %d required symbol(s) missing:@."
        (List.length symbols);
      List.iter symbols ~f:(fun s -> Fmt.pr "  - %s@." s)
  | Unknown ->
      Fmt.pr "PREDICTION: UNKNOWN — one side has no usable symbol data.@.";
      Fmt.pr "  stub.requires: %d, lib.symbols: %d@."
        (List.length stub.requires) (List.length lib.symbols)

let run ~stub_path ~lib_path =
  let stub = load_stub stub_path in
  let lib = load_native lib_path in
  let result = check_c_compat ~binding_stub:stub ~native_lib:lib in
  print_result ~stub ~lib result;
  match result with
  | Compatible | Unknown -> 0
  | Missing _ -> 1

(* ── Convenience: locate cached summaries for a (project, variant) pair ── *)

(* v3 layout: projects/{project}/{step_dir}/file_{variant_id}.ext
   step_dir = Canary_basic.step_dir_of_tag (e.g. "pack_binding/ocaml").
   variant_id is a filename suffix, not a subdir.
   For single-variant projects (variant_id = ""), filenames have no suffix.

   Resolve a variant arg to (project_dir, resolved_variant_id).
   Expands prefix matches: "dev" → "dev_ab43cb8" (most-recent by mtime)
   by scanning for variant-suffixed summary files in known step dirs.
   Returns None only when project_dir does not exist. *)
let resolve_variant ~root ~project variant =
  let project_dir = [%string "%{root}/_out/canary/projects/%{project}"] in
  if not (Stdlib.Sys.file_exists project_dir && Stdlib.Sys.is_directory project_dir)
  then None
  else if String.is_empty variant then
    Some (project_dir, "")
  else begin
    let find_variant_in_step step_dir_name =
      let step_dir = [%string "%{project_dir}/%{step_dir_name}"] in
      if not (Stdlib.Sys.file_exists step_dir && Stdlib.Sys.is_directory step_dir)
      then None
      else begin
        let exact_file = [%string "summary_%{variant}.json"] in
        if Stdlib.Sys.file_exists [%string "%{step_dir}/%{exact_file}"] then
          Some variant
        else begin
          let prefix = [%string "summary_%{variant}_"] in
          let candidates =
            Stdlib.Sys.readdir step_dir
            |> Array.to_list
            |> List.filter_map ~f:(fun f ->
                if String.is_prefix f ~prefix && String.is_suffix f ~suffix:".json" then
                  let tail = String.chop_prefix_exn f ~prefix in
                  let id_part = String.chop_suffix_exn tail ~suffix:".json" in
                  Some ([%string "%{step_dir}/%{f}"], [%string "%{variant}_%{id_part}"])
                else None)
            |> List.filter ~f:(fun (p, _) -> Stdlib.Sys.file_exists p)
          in
          match candidates with
          | [] -> None
          | xs ->
              let with_mtime = List.map xs ~f:(fun (p, d) ->
                  ((Unix.stat p).st_mtime, d))
              in
              let sorted = List.sort with_mtime
                  ~compare:(fun (a, _) (b, _) -> Float.compare b a) in
              Some (snd (List.hd_exn sorted))
        end
      end
    in
    let step_candidates = [
      "build_lib"; "probe_lib";
      "pack_binding/ocaml"; "fetch_binding/ocaml"; "build_binding/ocaml";
      "fetch_binding/python"; "build_binding/python";
      "probe_binding/ocaml"; "probe_binding/python";
    ] in
    let resolved = List.find_map step_candidates ~f:find_variant_in_step in
    Some (project_dir, Option.value resolved ~default:variant)
  end

(* Build a step-output path in the v3 layout.
   step_dir_of_tag converts e.g. "probe_binding_ocaml" → "probe_binding/ocaml".
   variant_id is encoded as a filename suffix (e.g. "probe_19.log"). *)
let step_path ~project_dir ~variant_id step rel =
  let step_d = Canary_basic.step_dir_of_tag step in
  let rel_vk = Canary_basic.variant_file ~variant_key:variant_id rel in
  [%string "%{project_dir}/%{step_d}/%{rel_vk}"]

let step_dir ~project_dir step =
  let step_d = Canary_basic.step_dir_of_tag step in
  [%string "%{project_dir}/%{step_d}"]

(* Pick the first existing probe_lib*/summary.json. *)
let find_lib_inspect ~project_dir ~variant_id =
  let candidates = [
    "build_lib";  (* tiny: lib inspect lives here (Phase 14d onward) *)
    "probe_lib"; "probe_lib_apt"; "probe_lib_brew"; "probe_lib_staged"
  ] in
  List.find_map candidates ~f:(fun step ->
      let d = step_dir ~project_dir step in
      let fname = Canary_basic.filename ~variant_key:variant_id ~base:"inspect" ~ext:"json" in
      let p = d ^ "/" ^ fname in
      if Stdlib.Sys.file_exists p then Some p else None)

(* OCaml binding summaries (mli + stub) are written by the install step —
   either Fetch (Binding OCaml) → fetch_binding/ocaml/, or
   Publish (Binding OCaml) → pack_binding/ocaml/. Try both. *)
let find_ocaml_install_dir ~project_dir =
  let candidates = [ "pack_binding_ocaml"; "fetch_binding_ocaml" ] in
  List.find_map candidates ~f:(fun step ->
      let p = step_dir ~project_dir step in
      if Stdlib.Sys.file_exists p && Stdlib.Sys.is_directory p
      then Some p else None)

(* Python binding summary is at fetch_binding/python/summary_{vk}.json. *)
let find_python_inspect ~project_dir ~variant_id =
  let d = step_dir ~project_dir "fetch_binding_python" in
  let fname = Canary_basic.filename ~variant_key:variant_id ~base:"inspect" ~ext:"json" in
  let p = d ^ "/" ^ fname in
  if Stdlib.Sys.file_exists p then Some p else None

let find_stub_inspect ~project_dir ~variant_id =
  Option.bind (find_ocaml_install_dir ~project_dir) ~f:(fun dir ->
      let fname = Canary_basic.filename ~variant_key:variant_id ~base:"inspect_stub" ~ext:"json" in
      let p = dir ^ "/" ^ fname in
      if Stdlib.Sys.file_exists p then Some p else None)

let find_mli_inspect ~project_dir ~variant_id =
  Option.bind (find_ocaml_install_dir ~project_dir) ~f:(fun dir ->
      let fname = Canary_basic.filename ~variant_key:variant_id ~base:"inspect" ~ext:"json" in
      let p = dir ^ "/" ^ fname in
      if Stdlib.Sys.file_exists p then Some p else None)

let run_for_project ~root ~project ~variant =
  match resolve_variant ~root ~project variant with
  | None ->
      Fmt.epr "compat: no project dir for %s under _out/canary/projects/@." project;
      2
  | Some (project_dir, variant_id) ->
      let stub_path = find_stub_inspect ~project_dir ~variant_id in
      let lib_path = find_lib_inspect ~project_dir ~variant_id in
      (match stub_path, lib_path with
       | None, _ ->
           Fmt.epr "compat: no inspect_stub.json under %s/pack_binding/ocaml/@."
             project_dir;
           Fmt.epr "  (run `canary action %s` first to populate the cache)@." project;
           2
       | _, None ->
           Fmt.epr "compat: no probe_lib*/summary.json under %s/@." project_dir;
           2
       | Some stub_p, Some lib_p ->
           Fmt.pr "(using cached summaries for %s/%s)@." project variant_id;
           run ~stub_path:stub_p ~lib_path:lib_p)

(* ── Verification: prediction vs probe outcome ── *)

(* Match a watchlist-missing entry against a probe.log. Tries the full path,
   the path without the top-level package component, and the last component.
   Returns the matched substring (if any). *)
let match_in_log ~log entry =
  let parts = String.split entry ~on:'.' in
  let candidates =
    entry ::
    (match parts with
     | _ :: rest when List.length rest >= 1 ->
         [ String.concat ~sep:"." rest ]
     | _ -> [])
    @ (match List.last parts with Some last -> [ last ] | None -> [])
  in
  List.find candidates ~f:(fun c -> String.is_substring log ~substring:c)

let read_file_or_empty path =
  if Stdlib.Sys.file_exists path
  then Stdlib.In_channel.with_open_text path Stdlib.In_channel.input_all
  else ""

let load_mli_missing ~project_dir ~variant_id =
  match find_mli_inspect ~project_dir ~variant_id with
  | None -> []
  | Some p ->
      let j = Yojson.Basic.from_file p in
      match field j "watchlist" with
      | Some wl -> get_string_list wl "missing"
      | None -> []

(* Variants of a dotted name suitable for substring matching against a
   probe.log: full path, suffix without top-level package prefix, last
   component. Same logic for OCaml ("Llvm.Opcode.UncondBr" → also
   "Opcode.UncondBr" and "UncondBr") and Python ("z3.Solver" → also
   "Solver"). *)
let name_variants e =
  let parts = String.split e ~on:'.' in
  let suffix_no_top = match parts with
    | _ :: (_ :: _ as rest) -> [ String.concat ~sep:"." rest ]
    | _ -> []
  in
  let last = match List.last parts with Some l -> [ l ] | None -> [] in
  e :: suffix_no_top @ last

let load_watchlist_missing path =
  if not (Stdlib.Sys.file_exists path) then []
  else
    let j = Yojson.Basic.from_file path in
    match field j "watchlist" with
    | Some wl -> get_string_list wl "missing"
    | None -> []

(** Predict substrings that would appear in a failed [probe.log] given
    cached inspector JSON paths. Legacy positional API kept for back-
    compat; new call sites should use {!predicted_contains_any_v2}.

    Combines two prediction layers:
    - [stub_inspect_path] + [lib_inspect_path] → {i c1 cmp_symbol}
      missing-symbol prediction (set diff: stub requires \ lib defines).
      Driven by {i bo7} + {i n4} for OCaml or {i bpe3} + {i n4} for cext.
    - [mli_inspect_path] → {i c2 cmp_api_completeness} watchlist-missing
      prediction. Driven by {i bo4 user_binding_ocaml.mli}'s inspect JSON. *)
let predicted_contains_any
    ?stub_inspect_path ?lib_inspect_path ?mli_inspect_path () =
  let l3 = Option.value_map mli_inspect_path ~default:[] ~f:load_watchlist_missing in
  let l3_variants =
    List.concat_map l3 ~f:name_variants
    |> List.dedup_and_sort ~compare:String.compare
  in
  let l0 = match stub_inspect_path, lib_inspect_path with
    | Some s, Some l
      when Stdlib.Sys.file_exists s && Stdlib.Sys.file_exists l ->
        let stub = load_stub s in
        let lib = load_native l in
        (match check_c_compat ~binding_stub:stub ~native_lib:lib with
         | Missing { symbols } -> symbols
         | Compatible | Unknown -> [])
    | _ -> []
  in
  l3_variants @ l0
  |> List.dedup_and_sort ~compare:String.compare

(* ── Contract registry (Phase 12, 2026-06-02) ─────────────────────────
   Each c* contract is a registered entry with its own predict closure.
   [predicted_contains_any_v2] is a 4-line iterator over the registry;
   adding a new c* = one more registry entry + one predict function.

   The types live in {!Canary_compat} so consumers can name
   [contract_id] / [contract_status] without opening this file. *)

let pick_existing ~resolve paths =
  List.find_map paths ~f:(fun rel ->
    let abs = resolve rel in
    if Stdlib.Sys.file_exists abs then Some abs else None)

(** c1 cmp_symbol (L0). Pairs C_stub + Native_lib paths and returns
    the missing C symbols from {!check_c_compat}. *)
let c1_predict ~resolve (inputs : inspect_input list) : string list =
  let stub_path =
    List.find_map inputs
      ~f:(function C_stub ps -> pick_existing ~resolve ps | _ -> None)
  in
  let lib_path =
    List.find_map inputs
      ~f:(function Native_lib ps -> pick_existing ~resolve ps | _ -> None)
  in
  match stub_path, lib_path with
  | Some s, Some l ->
      let stub = load_stub s in
      let lib = load_native l in
      (match check_c_compat ~binding_stub:stub ~native_lib:lib with
       | Missing { symbols } -> symbols
       | Compatible | Unknown -> [])
  | _ -> []

(** c2 cmp_api_completeness (L3). Reads watchlist_missing from
    Ocaml_mli / Python_attrs JSONs and expands each missing name into
    its observable variants (e.g. [Llvm.Opcode.UncondBr] →
    [Opcode.UncondBr], [UncondBr]). *)
let c2_predict ~resolve (inputs : inspect_input list) : string list =
  List.concat_map inputs ~f:(function
    | Ocaml_mli ps | Python_attrs ps ->
        (match pick_existing ~resolve ps with
         | None -> []
         | Some p -> load_watchlist_missing p |> List.concat_map ~f:name_variants)
    | _ -> [])

(** c5 cmp_sym_version (L1b). Reads provider's versioned_exports map
    from a [Versioned_exports] input and consumer's versioned_req map
    from a [Versioned_req] input; runs [check_sym_version] and on
    mismatch returns the version tags the consumer requires that the
    provider doesn't export. dyld's runtime error mentions those tags
    verbatim ("version `TINY_1.0' not found"), so they're the right
    substrings to grep probe.log for. *)
let c5_predict ~resolve (inputs : inspect_input list) : string list =
  let provider_path =
    List.find_map inputs
      ~f:(function
        | Versioned_exports ps -> pick_existing ~resolve ps
        | _ -> None) in
  let consumer_path =
    List.find_map inputs
      ~f:(function
        | Versioned_req ps -> pick_existing ~resolve ps
        | _ -> None) in
  match provider_path, consumer_path with
  | Some pp, Some cp ->
      let prov = Canary_compat.load_versioned_symbols pp in
      let cons = Canary_compat.load_versioned_symbols cp in
      let consumer_required = List.map cons.req_counts ~f:fst in
      (match Canary_compat.check_sym_version
               ~provider_versioned_exports:prov.exports
               ~consumer_required_versions:consumer_required with
       | Sym_version_missing { missing_versions } -> missing_versions
       | Sym_version_compatible | Sym_version_unknown -> [])
  | _ -> []

(** c4 cmp_abi (L4). Reads provider's SONAME from a [Native_lib]
    input's [elf.soname] and consumer's NEEDED list from an
    [Abi_surface] input's [elf.needed]. When [check_abi] returns
    [Abi_mismatch], the predicted substring set is the consumer's
    NEEDED entries that share the provider's family-stem
    (e.g. [libtiny] from [libtiny.so.1]) — at runtime, dyld's error
    mentions the missing NEEDED entry verbatim, so that's what we want
    to grep for. *)
let c4_predict ~resolve (inputs : inspect_input list) : string list =
  let provider_path =
    List.find_map inputs
      ~f:(function Native_lib ps -> pick_existing ~resolve ps | _ -> None) in
  let consumer_path =
    List.find_map inputs
      ~f:(function Abi_surface ps -> pick_existing ~resolve ps | _ -> None) in
  match provider_path, consumer_path with
  | Some pp, Some cp ->
      let prov = Canary_compat.load_abi_surface pp in
      let cons = Canary_compat.load_abi_surface cp in
      (match Canary_compat.check_abi
               ~provider_soname:prov.soname
               ~consumer_needed:cons.needed with
       | Abi_mismatch _ ->
           (* Stem = strip trailing ".so.X" / ".so.X.Y" so libtiny.so.1
              and libtiny.so.2 share stem "libtiny". *)
           let stem name =
             match String.index name '.' with
             | None -> name
             | Some i -> String.sub name ~pos:0 ~len:i in
           (match prov.soname with
            | None -> []
            | Some sn ->
                let prov_stem = stem sn in
                List.filter cons.needed
                  ~f:(fun n -> String.equal (stem n) prov_stem))
       | Abi_compatible | Abi_unknown -> [])
  | _ -> []

(** c3 cmp_behavior is structurally different from c1/c2/c4/c5.
    There's no static input to predict over — behavioral truth lives
    in the {b running} binary, and expected values live inside the
    probe's source as embedded assertions. The comparator IS the
    probe's exit-code check; canary surfaces it via
    [Expect_failure { contains_any = ["FAIL "] }] on Probe steps (the
    tiny probe prints [FAIL …] on assertion mismatch).
    See [Canary_tiny_scenario.make_lib_behavior_broken_runner_spec]
    for the demo against harness scenario [e7 behavior_silent].
    [c3_predict] returns [] honestly: there's nothing static to
    predict. Status stays [Blocked []] to reflect the {b predict} side
    being a no-op; coverage is via the probe runner.

    c7 [api_sound_repack] is structurally analogous to c3 — same
    probe-runner mechanism, different Contract attribution (binding-
    repack-layer bug vs native-behavior bug). Variants declaring c7
    use [Expect_failure { contains_any = ["FAIL "] }] same as c3.
    [c7_predict] returns []; registry entry stays in place for
    documentation only (status = Stubbed, enabled = false). See
    [Canary_tiny_scenario.make_binding_repack_broken_runner_spec] and
    [make_binding_python_repack_broken_runner_spec] for live demos
    against scenarios [api_repack] and [api_repack_python].

    c8 is disabled — no Contract for canary to maintain. Each binding
    is independent; cross-binding consistency isn't a canary-side
    agreement. Candidate for removal in a future registry cleanup. *)
let c3_predict ~resolve:_ _ = []
let c7_predict ~resolve:_ _ = []
let c8_predict ~resolve:_ _ = []

(** c6 cmp_type (L2). Pairs a [Typed_header] input (provider's C
    signatures, n3) with a [Typed_binding_stub] input (consumer's
    stub-facing typed surface, bo1 / bpe1 — the binding's expectation
    of the C ABI). For each function present on both sides, checks
    whether the signatures agree (same return type, same arg type
    list). Mismatching names are returned as predicted substrings —
    the compiler error message for an arity / type clash mentions the
    function name verbatim (e.g.
    `error: too few arguments to function 'tiny_sum'`).

    Names present in only one side aren't c6 — they're c1
    (cmp_symbol's domain). c6 only fires when both sides claim the
    function but disagree on its signature. *)
let c6_predict ~resolve (inputs : inspect_input list) : string list =
  let header_path =
    List.find_map inputs
      ~f:(function Typed_header ps -> pick_existing ~resolve ps | _ -> None) in
  let stub_path =
    List.find_map inputs
      ~f:(function Typed_binding_stub ps -> pick_existing ~resolve ps
                 | _ -> None) in
  match header_path, stub_path with
  | Some hp, Some sp ->
      let h = Canary_compat.load_typed_signatures hp in
      let s = Canary_compat.load_typed_signatures sp in
      List.filter_map h.functions ~f:(fun (name, h_sig) ->
        match List.Assoc.find s.functions name ~equal:String.equal with
        | None -> None
        | Some s_sig ->
            if String.equal h_sig.return_type s_sig.return_type
               && List.equal String.equal h_sig.arg_types s_sig.arg_types
            then None
            else Some name)
  | _ -> []

(** The contract registry. Single source of truth for §2.4 of
    [surface_theory.md] — adding a contract = adding one entry. *)
let registered_checks : contract_check list = [
  { id = C1; name = "cmp_symbol";            layer = "L0";  status = Wired;
    enabled = true;  predict = c1_predict };
  { id = C2; name = "cmp_api_completeness";  layer = "L3";  status = Wired;
    enabled = true;  predict = c2_predict };
  { id = C3; name = "cmp_behavior";          layer = "dyn"; status = Blocked [];
    enabled = false; predict = c3_predict };
  { id = C4; name = "cmp_abi";               layer = "L4";  status = Wired;
    enabled = true;  predict = c4_predict };
  { id = C5; name = "cmp_sym_version";       layer = "L1b"; status = Wired;
    enabled = true;  predict = c5_predict };
  { id = C6; name = "cmp_type";              layer = "L2";  status = Wired;
    enabled = true;  predict = c6_predict };
  (* c7 api_sound_repack — Contract that the binding's user-facing
     layer is a sound repacking of its stub-facing layer. Same check
     shape as c3 (probe-assertion refutation), different Contract
     (binding-layer bug vs native-layer bug). The probe IS the
     binding-side test; predict returns []. The variant declaration
     attributes the failure to c7 — canary doesn't disambiguate at
     the detection layer. See
     [Canary_tiny_scenario.make_binding_repack_broken_runner_spec]
     for the demo against harness scenario [api_repack] (e5). *)
  { id = C7; name = "api_sound_repack";      layer = "dyn"; status = Stubbed;
    enabled = false; predict = c7_predict };
  (* c8 disabled — no Contract for canary to maintain. Each binding
     is independent; cross-binding consistency isn't a canary-side
     agreement to check. Probes happen to assert the same constants
     across languages by project convention, not by a Contract.
     Candidate for removal in a future registry cleanup. *)
  { id = C8; name = "cmp_api_faithfulness";  layer = "n/a"; status = Stubbed;
    enabled = false; predict = c8_predict };
]

(** Derive expected failure substrings from declared inspector inputs.

    [resolve] turns a per-input relative path (e.g.
    [pack_binding_ocaml/inspect_stub.json]) into an absolute path. The
    runner picks the first input path whose resolved form exists on
    disk, then hands it to the pure comparators in {!Canary_compat}.

    [?disabled] is the per-call list of contracts to skip on top of
    the registry's own [enabled] flag. Typical sources:
    - per-project: [runner_spec.disabled_contracts]
    - per-CLI: the [--disable-contract c5,c4] flag on canary action / compat / verify
    A contract fires iff its registry [enabled] is true AND its id is
    not in [disabled].

    Phase 12 (2026-06-02): the four L0/L1b/L3/L4 sections of this
    function moved into per-contract predict closures registered in
    [registered_checks]. The body is now a flat iterator over the
    registry. Behaviour is unchanged with default [?disabled = []] —
    c1, c2, c5 fire as before; c4 returns [].

    Phase 13 (2026-06-02): per-call [?disabled] override added. *)
(** Per-contract form (A7 phase 1): the registry rows that FIRED — each
    enabled, not-disabled contract whose [predict] returned substrings —
    paired with its (deduped) substrings. {!predicted_contains_any_v2} is
    its flatten; keeping the grouping lets the runner log and report
    per-contract firings instead of one collapsed count (the status-§2
    "per-step contract outcome" seed). *)
let predicted_by_contract_v2 ?(disabled = []) ~resolve
    (inputs : inspect_input list) : (contract_check * string list) list =
  List.filter_map registered_checks ~f:(fun c ->
    if c.enabled && not (List.mem disabled c.id ~equal:Poly.equal) then
      match c.predict ~resolve inputs with
      | [] -> None
      | subs -> Some (c, List.dedup_and_sort ~compare:String.compare subs)
    else None)

(** The registry rows a [predicted_by_contract_v2] call does NOT consult,
    each with its human reason — the per-call [?disabled] override (a
    project's [disabled_contracts] / --disable-contract) vs the registry's
    own [enabled] flag (status names why). For the runner's
    [contract_skipped] events. *)
let skipped_checks ?(disabled = []) () : (contract_check * string) list =
  List.filter_map registered_checks ~f:(fun c ->
    if List.mem disabled c.id ~equal:Poly.equal then
      Some (c, "disabled per call")
    else if not c.enabled then
      Some
        ( c,
          "disabled in registry ("
          ^ Canary_compat.string_of_contract_status c.status
          ^ ")" )
    else None)

let predicted_contains_any_v2 ?(disabled = []) ~resolve
    (inputs : inspect_input list) : string list =
  predicted_by_contract_v2 ~disabled ~resolve inputs
  |> List.concat_map ~f:snd
  |> List.dedup_and_sort ~compare:String.compare

(* Best-effort: ".ok" marker file alongside cmd success implies probe step
   succeeded. probe.log non-empty + no .ok marker implies cmd failed (which
   for Expect_failure cases is the GOAL — see step_expectation in
   canary_action.ml). We're not re-implementing the runner's verdict; just
   distinguishing "log has compile error text" from "log shows runtime ok". *)
let probe_log_inspect log =
  let lines = String.split_lines log in
  let line_count = List.length lines in
  let head = List.take lines 4 |> String.concat ~sep:"\n" in
  (line_count, head)

let verify_for_project ~root ~project ~variant =
  match resolve_variant ~root ~project variant with
  | None ->
      Fmt.epr "verify: no project dir for %s under _out/canary/projects/@." project;
      2
  | Some (project_dir, variant_id) ->
      Fmt.pr "=== Compat verification: %s/%s ===@.@." project variant_id;
      Fmt.pr "Project dir: %s  variant: %s@.@." project_dir
        (if String.is_empty variant_id then "(single-variant)" else variant_id);

      (* L3 (OCaml mli) prediction *)
      let mli_missing = load_mli_missing ~project_dir ~variant_id in
      Fmt.pr "L3 (OCaml mli) prediction:@.";
      if List.is_empty mli_missing then
        Fmt.pr "  watchlist missing: (none) — predicts SUCCESS at OCaml level@."
      else (
        Fmt.pr "  watchlist missing: %d entry/entries@."
          (List.length mli_missing);
        List.iter mli_missing ~f:(fun e -> Fmt.pr "    - %s@." e);
        Fmt.pr "  → predicts FAIL referencing one of these names@.");

      (* L3 (Python attrs) prediction *)
      let py_missing =
        match find_python_inspect ~project_dir ~variant_id with
        | None -> []
        | Some p -> load_watchlist_missing p
      in
      Fmt.pr "@.L3 (Python attrs) prediction:@.";
      (match find_python_inspect ~project_dir ~variant_id with
       | None -> Fmt.pr "  (no Python summary cached at fetch_binding_python/)@."
       | Some _ ->
           if List.is_empty py_missing then
             Fmt.pr "  watchlist missing: (none) — predicts SUCCESS at Python level@."
           else (
             Fmt.pr "  watchlist missing: %d entry/entries@."
               (List.length py_missing);
             List.iter py_missing ~f:(fun e -> Fmt.pr "    - %s@." e);
             Fmt.pr "  → predicts FAIL referencing one of these names@."));

      (* L0 (C symbols) prediction *)
      let stub_path = find_stub_inspect ~project_dir ~variant_id in
      let lib_path = find_lib_inspect ~project_dir ~variant_id in
      let c_result = match stub_path, lib_path with
        | Some s, Some l ->
            let stub = load_stub s in
            let lib = load_native l in
            Some (stub, lib, check_c_compat ~binding_stub:stub ~native_lib:lib)
        | _ -> None
      in
      Fmt.pr "@.L0 (C symbols) prediction:@.";
      let c_missing = match c_result with
        | None -> Fmt.pr "  (summaries unavailable)@."; []
        | Some (stub, lib, Compatible) ->
            Fmt.pr "  binding requires %d symbols, lib provides %d@."
              (List.length stub.requires) (List.length lib.symbols);
            Fmt.pr "  → predicts COMPATIBLE at C ABI level@.";
            []
        | Some (stub, lib, Missing { symbols }) ->
            Fmt.pr "  binding requires %d symbols, lib provides %d@."
              (List.length stub.requires) (List.length lib.symbols);
            Fmt.pr "  missing: %d C symbol(s)@." (List.length symbols);
            List.iter symbols ~f:(fun s -> Fmt.pr "    - %s@." s);
            Fmt.pr "  → predicts FAIL referencing one of these symbols@.";
            symbols
        | Some (_, _, Unknown) ->
            Fmt.pr "  (UNKNOWN — one side has no usable symbol data)@.";
            []
      in

      (* Probe.log analysis *)
      let read_log step =
        read_file_or_empty (step_path ~project_dir ~variant_id step "probe.log")
      in
      let ocaml_log = read_log "probe_binding_ocaml" in
      let python_log = read_log "probe_binding_python" in
      let print_log_section name log =
        let line_count, head = probe_log_inspect log in
        Fmt.pr "@.%s probe.log analysis (%d lines):@." name line_count;
        if String.is_empty log then Fmt.pr "  (empty or missing)@."
        else (
          Fmt.pr "  head:@.";
          List.iter (String.split_lines head) ~f:(fun l ->
              Fmt.pr "    | %s@." l))
      in
      print_log_section "OCaml" ocaml_log;
      if not (String.is_empty python_log) then
        print_log_section "Python" python_log;

      (* Cross-reference predictions vs log *)
      Fmt.pr "@.Verdict:@.";
      let confirmed_in log entries =
        List.filter_map entries ~f:(fun e ->
            Option.map (match_in_log ~log e) ~f:(fun m -> (e, m)))
      in
      let unconfirmed_in log entries =
        List.filter entries ~f:(fun e ->
            Option.is_none (match_in_log ~log e))
      in
      let l3_ocaml_confirmed = confirmed_in ocaml_log mli_missing in
      let l3_ocaml_unconfirmed = unconfirmed_in ocaml_log mli_missing in
      let l3_python_confirmed = confirmed_in python_log py_missing in
      let l3_python_unconfirmed = unconfirmed_in python_log py_missing in
      let l0_confirmed =
        List.filter c_missing ~f:(fun s ->
            String.is_substring ocaml_log ~substring:s)
      in
      let l0_unconfirmed =
        List.filter c_missing ~f:(fun s ->
            not (String.is_substring ocaml_log ~substring:s))
      in

      let print_verdict_layer layer ~log ~predicted ~confirmed ~unconfirmed =
        match predicted, confirmed, unconfirmed with
        | [], _, _ ->
            Fmt.pr "  %s: predicted COMPATIBLE — %s@." layer
              (if String.is_empty log then "(no probe log to verify against)"
               else "no failure expected at this layer")
        | _, [], _ ->
            Fmt.pr "  %s: prediction NOT visible in log — probe may have \
                    failed for a different reason, or didn't reach this layer@." layer
        | _, _, [] ->
            Fmt.pr "  %s: CONFIRMED — all predicted entries appear in probe.log@." layer
        | _ ->
            Fmt.pr "  %s: PARTIAL — %d/%d predicted entries confirmed@."
              layer (List.length confirmed)
              (List.length predicted)
      in
      print_verdict_layer "L3 (OCaml)" ~log:ocaml_log
        ~predicted:mli_missing ~confirmed:(List.map l3_ocaml_confirmed ~f:fst)
        ~unconfirmed:l3_ocaml_unconfirmed;
      print_verdict_layer "L3 (Python)" ~log:python_log
        ~predicted:py_missing ~confirmed:(List.map l3_python_confirmed ~f:fst)
        ~unconfirmed:l3_python_unconfirmed;
      print_verdict_layer "L0 (C ABI)" ~log:ocaml_log
        ~predicted:c_missing ~confirmed:l0_confirmed
        ~unconfirmed:l0_unconfirmed;
      List.iter (l3_ocaml_confirmed @ l3_python_confirmed) ~f:(fun (entry, matched) ->
          if not (String.equal entry matched) then
            Fmt.pr "    note: '%s' matched as substring '%s'@." entry matched);
      0

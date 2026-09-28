(** THE MANIFEST: what a run realized (2026-09-28, design/overview.md §6.4
    step 6).

    The run record ({!Canary_matrix.matrix_of}) rebuilt each world's steps
    from TODAY's code, on the machine that renders, and joined the log to
    them by tag. That is right only while the code and the machine have not
    changed since the run: a step a later edit added reads as never run, a
    step it removed disappears with its verdicts, and a mac log read on WSL
    is joined to WSL's steps. The runner now writes, for each world it runs,
    the steps it realized — the way a compiler writes debug information
    beside its object code — and the record reads that where it exists,
    re-deriving only for a world no run has recorded.

    Only the typed facts a reader needs: each step's tag (the id its log
    lines carry), its action, where a probe looks, what an inspection
    inspects, why a dummy is empty, the bridge it drives, the placeholder it
    stands for, and its dependencies. No command and no path: those belong
    to the run, not to its record. *)

open Base

type entry = {
  me_tag : string;
  me_action : Canary_basic.action;
  me_location : Canary_store.location option;
  me_inspects : string option;
  me_dummy : string option;
  me_bridge : Canary_bridge.t option;
  me_placeholder : Canary_pm_action.placeholder option;
  me_deps : string list;
}

let of_step (s : Canary_step_model.step) : entry =
  { me_tag = s.Canary_step_model.tag;
    me_action = s.Canary_step_model.action;
    me_location = s.Canary_step_model.location;
    me_inspects = s.Canary_step_model.inspects;
    me_dummy = s.Canary_step_model.dummy;
    me_bridge = s.Canary_step_model.bridge;
    me_placeholder = s.Canary_step_model.placeholder;
    me_deps = s.Canary_step_model.deps }

(* ── the codecs ── *)

let langs = Canary_lang.[ Cpp; OCaml; Python; Rust; CSharp; Java ]
let pms = Canary_store.[ Apt; Brew; Opam; Pip; Unsupported ]

(** EVERY ACTION THERE IS, enumerated from the type — what an action's
    spelling is decoded against, so the codec is total over the type rather
    than over the spellings one parser learned ([Canary_basic.action_of_string]
    does not read a binding source's fetch). *)
let all_actions : Canary_basic.action list =
  let open Canary_basic in
  let kinds =
    [ Source; Headers; Lib; App ]
    @ List.concat_map langs ~f:(fun l -> [ Binding l; Binding_source l ])
  in
  [ Configure; Scan_sources; Build_headers; Build_lib; Install_lib; Probe_lib ]
  @ List.concat_map kinds ~f:(fun k -> [ Fetch k; Publish k ])
  @ List.concat_map langs ~f:(fun l ->
        [ Build_binding l; Probe_binding l; Build_app { lang = l }; Probe_app { lang = l } ])

let find_by (f : 'a -> string) (xs : 'a list) (s : string) : 'a option =
  List.find xs ~f:(fun x -> String.equal (f x) s)

let action_of_name : string -> Canary_basic.action option =
  find_by Canary_basic.string_of_action all_actions

let field j k = match j with `Assoc kv -> List.Assoc.find kv k ~equal:String.equal | _ -> None
let str j k = match field j k with Some (`String s) -> Some s | _ -> None

let json_of_location : Canary_store.location -> Yojson.Basic.t = function
  | Canary_store.Build_tree -> `Assoc [ ("at", `String "build_tree") ]
  | Canary_store.Staged -> `Assoc [ ("at", `String "staged") ]
  | Canary_store.Pm (Canary_store.Sys_pm { pm }) ->
      `Assoc [ ("at", `String "sys_pm"); ("pm", `String (Canary_store.string_of_pm pm)) ]
  | Canary_store.Pm (Canary_store.Lang_pm { lang; pm }) ->
      `Assoc
        [ ("at", `String "lang_pm");
          ("lang", `String (Canary_lang.string_of_lang lang));
          ("pm", `String (Canary_store.string_of_pm pm)) ]

let location_of_json (j : Yojson.Basic.t) : Canary_store.location option =
  let pm = Option.bind (str j "pm") ~f:(find_by Canary_store.string_of_pm pms) in
  let lang = Option.bind (str j "lang") ~f:(find_by Canary_lang.string_of_lang langs) in
  match (str j "at", pm, lang) with
  | Some "build_tree", _, _ -> Some Canary_store.Build_tree
  | Some "staged", _, _ -> Some Canary_store.Staged
  | Some "sys_pm", Some pm, _ -> Some (Canary_store.Pm (Canary_store.Sys_pm { pm }))
  | Some "lang_pm", Some pm, Some lang -> Some (Canary_store.Pm (Canary_store.Lang_pm { lang; pm }))
  | _ -> None

let bridge_of_json : Yojson.Basic.t -> Canary_bridge.t option = function
  | `String s -> (
      match String.chop_prefix s ~prefix:"depext:" with
      | Some d -> Some (Canary_bridge.Opam (Canary_bridge.Depext_field d))
      | None -> Some (Canary_bridge.Opam (Canary_bridge.Conf_package s)))
  | _ -> None

let json_of_placeholder (p : Canary_pm_action.placeholder) : Yojson.Basic.t =
  let code, why =
    match p.Canary_pm_action.ph_unseen with
    | Canary_pm_action.Not_yet t -> ("not_yet", t)
    | Canary_pm_action.Out_of_reach t -> ("out_of_reach", t)
  in
  `Assoc
    [ ("pm", `String (Canary_store.string_of_pm p.Canary_pm_action.ph_pm));
      ("key", `String p.Canary_pm_action.ph_key);
      ("does", `String (Canary_pm_action.string_of_does p.Canary_pm_action.ph_does));
      ("what", `String p.Canary_pm_action.ph_what);
      ("unseen", `String code);
      ("why", `String why) ]

let placeholder_of_json (j : Yojson.Basic.t) : Canary_pm_action.placeholder option =
  let does =
    find_by Canary_pm_action.string_of_does Canary_pm_action.[ Resolve; Build_package ]
  in
  let unseen =
    match (str j "unseen", str j "why") with
    | Some "not_yet", Some t -> Some (Canary_pm_action.Not_yet t)
    | Some "out_of_reach", Some t -> Some (Canary_pm_action.Out_of_reach t)
    | _ -> None
  in
  match
    ( Option.bind (str j "pm") ~f:(find_by Canary_store.string_of_pm pms),
      str j "key",
      Option.bind (str j "does") ~f:does,
      str j "what",
      unseen )
  with
  | Some pm, Some key, Some d, Some what, Some u ->
      Some
        { Canary_pm_action.ph_pm = pm; ph_key = key; ph_does = d; ph_what = what; ph_unseen = u }
  | _ -> None

let json_of_entry (e : entry) : Yojson.Basic.t =
  let opt f = function Some x -> f x | None -> `Null in
  let s x = `String x in
  `Assoc
    [ ("tag", s e.me_tag);
      ("action", s (Canary_basic.string_of_action e.me_action));
      ("location", opt json_of_location e.me_location);
      ("inspects", opt s e.me_inspects);
      ("dummy", opt s e.me_dummy);
      ("bridge", opt (fun b -> s (Canary_bridge.to_string b)) e.me_bridge);
      ("placeholder", opt json_of_placeholder e.me_placeholder);
      ("deps", `List (List.map e.me_deps ~f:s)) ]

(** A field that is present must decode; one that is absent or null is
    [None]. An entry with any field this code cannot read is [None] as a
    whole, rather than a step with a fact quietly dropped. *)
let entry_of_json (j : Yojson.Basic.t) : entry option =
  let optional k decode =
    match field j k with
    | None | Some `Null -> Some None
    | Some v -> Option.map (decode v) ~f:Option.some
  in
  let string = function `String x -> Some x | _ -> None in
  match
    ( str j "tag",
      Option.bind (str j "action") ~f:action_of_name,
      optional "location" location_of_json,
      optional "inspects" string,
      optional "dummy" string,
      optional "bridge" bridge_of_json,
      optional "placeholder" placeholder_of_json )
  with
  | Some tag, Some action, Some location, Some inspects, Some dummy, Some bridge, Some placeholder
    ->
      let deps =
        match field j "deps" with
        | Some (`List xs) -> List.filter_map xs ~f:string
        | _ -> []
      in
      Some
        { me_tag = tag;
          me_action = action;
          me_location = location;
          me_inspects = inspects;
          me_dummy = dummy;
          me_bridge = bridge;
          me_placeholder = placeholder;
          me_deps = deps }
  | _ -> None

(* ── on disk: one file per world, beside the project's log ── *)

let dir ~root ~project = Printf.sprintf "%s/canary/projects/%s/-run/manifest" root project
let path ~root ~project ~scenario = dir ~root ~project ^ "/" ^ scenario ^ ".json"

(** The steps a run realized for one world, with the machine and the opam
    switch it realized them for. Rewritten by every run of the world, as
    the log's last-wins reading expects. *)
let write ~root ~project ~scenario (steps : Canary_step_model.step list) : unit =
  (try Canary_step_model.ensure_dir (dir ~root ~project) with _ -> ());
  let j =
    `Assoc
      [ ("scenario", `String scenario);
        ("platform", `String (Canary_store.string_of_platform (Canary_store.platform ())));
        ("switch", `String (Canary_store.opam_switch_label ()));
        ("steps", `List (List.map steps ~f:(fun s -> json_of_entry (of_step s)))) ]
  in
  Stdio.Out_channel.write_all (path ~root ~project ~scenario) ~data:(Yojson.Basic.pretty_to_string j)

(** What a run recorded for this world, or [None] where no run wrote a
    manifest — or wrote one this code cannot read, in which case the record
    re-derives the world rather than showing half of it. *)
let read ~root ~project ~scenario : entry list option =
  match Yojson.Basic.from_file (path ~root ~project ~scenario) with
  | exception _ -> None
  | j -> (
      match field j "steps" with
      | Some (`List xs) ->
          let es = List.map xs ~f:entry_of_json in
          if List.for_all es ~f:Option.is_some then Some (List.filter_opt es) else None
      | _ -> None)

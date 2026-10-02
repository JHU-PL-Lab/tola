(** The agents' harness: checks of the repository's own text. The
    documents name live code and their references resolve, modules keep
    their declared shape, the ratchets hold, and every test and harness
    check is registered and says what it holds. Canary never runs these;
    the agent does, with [make harness], before committing. *)

open Base
open Canary_project_test
open Canary_tests

let agreement_dir = "src/canary/agreement"

(* A source file without its comments, nested ones included. The checks
   read code only, because a comment may name what the code may not. *)
let code_without_comments path =
  let s = Stdio.In_channel.read_all path in
  let buf = Buffer.create (String.length s) in
  let depth = ref 0 and i = ref 0 in
  let n = String.length s in
  while !i < n do
    if !i + 1 < n && Char.equal s.[!i] '(' && Char.equal s.[!i + 1] '*' then (
      Int.incr depth;
      i := !i + 2)
    else if
      !i + 1 < n && Char.equal s.[!i] '*' && Char.equal s.[!i + 1] ')'
      && !depth > 0
    then (
      Int.decr depth;
      i := !i + 2)
    else (
      if !depth = 0 then Buffer.add_char buf s.[!i];
      Int.incr i)
  done;
  Buffer.contents buf

(** The agreement families, as (module name, comment-free source). A
    family is a module that publishes [checks] and declares no
    [composes]: a property, not a filename convention, so renaming the
    files cannot empty the checks that read this. *)
let agreement_families () : (string * string) list =
  Sys_unix.readdir agreement_dir |> Array.to_list
  |> List.filter ~f:(String.is_suffix ~suffix:".ml")
  |> List.map ~f:(fun f ->
         ( String.capitalize (String.chop_suffix_exn f ~suffix:".ml"),
           code_without_comments (agreement_dir ^ "/" ^ f) ))
  |> List.filter ~f:(fun (_, code) ->
         String.is_substring code ~substring:"let checks"
         && not (String.is_substring code ~substring:"let composes"))

(* A count above the baseline: route the new use through a tool/
   primitive. A count below it: lower the baseline in the same commit,
   since the check fails only above. Comments count too; this is a
   ratchet, not a parser. *)
let tool_routing_ratchet_check : pure_test =
  { name = "harness.tool_routing_ratchet";
    holds = "No project spec file has more lines with a raw shell verb that should go through a tool primitive than its frozen baseline allows.";
    check = (fun () ->
      let dir = "src/canary/project" in
      let lines_with ~needle path =
        try
          Stdlib.In_channel.with_open_text path (fun ic ->
              let rec loop n =
                match Stdlib.In_channel.input_line ic with
                | None -> n
                | Some l ->
                    loop (if String.is_substring l ~substring:needle then n + 1 else n)
              in
              loop 0)
        with _ -> 0
      in
      (* verb -> per-file baseline; an unlisted file allows 0 *)
      let baseline =
        [ ("cmake ",
           [ (* llvm: comments *)
             ("canary_project_llvm.ml", 7); ("canary_tiny_scenario.ml", 4);
             (* z3: comments and the CI spec's [no_cmake] filter *)
             ("canary_project_z3.ml", 7); ("canary_run.ml", 1) ]);
          ("ninja ",
           [ (* comments: the -G Ninja note and the published-package probe *)
             ("canary_project_z3.ml", 2);
             (* a comment: the ninja LLVM dylib note *)
             ("canary_project_llvm.ml", 1) ]);
          ("gcc ", []);
          ("curl ", []);
          (* the flag form: the bare word is also in the primitive's name,
             curl_unzip_cmd, and only raw invocations count *)
          ("unzip -", []);
          ("pip install", [ ("canary_project_llvm.ml", 3) ]);
          ("opam install",
           [ ("canary_opam_binding.ml", 1);
             (* comments naming the routed verb *)
             ("canary_project_ssl.ml", 3);
             (* two comments and the publish row's own command *)
             ("canary_project_z3.ml", 3);
             (* the opam commands measured while landing torch, quoted in
                comments and the lib row's rationale: evidence, not shell *)
             ("canary_project_torch.ml", 5) ]);
          ("nm -D", [ ("canary_tiny_workspace.ml", 2) ]);
          ("git clone", []);
          ("tar ", []) ]
      in
      match Stdlib.Sys.readdir dir with
      | exception _ -> false
      | files ->
          let ok = ref true in
          Array.iter files ~f:(fun f ->
              if String.is_suffix f ~suffix:".ml" then
                List.iter baseline ~f:(fun (verb, per_file) ->
                    let allowed =
                      Option.value
                        (List.Assoc.find per_file f ~equal:String.equal)
                        ~default:0
                    in
                    let n = lines_with ~needle:verb (dir ^ "/" ^ f) in
                    if n > allowed then begin
                      ok := false;
                      Fmt.pr
                        "    RATCHET %s: %d line(s) with %S (baseline %d) — \
                         route new uses through src/canary/tool@."
                        f n verb allowed
                    end));
          !ok) }

(* Two boundaries are checked, not the section banners, so the shape
   holds without freezing the prose: the agreement declarations precede
   [let checks], which names them, and no type or evidence loader
   follows the first declaration. *)
let agreement_module_shape_check : pure_test =
  { name = "agreements.families_share_one_shape";
    holds = "Each of the at least five agreement families declares its agreements before the checks list gathering them, and no type or loader after them.";
    check =
      (fun () ->
        match Sys_unix.file_exists agreement_dir with
        | `No | `Unknown -> true
        | `Yes ->
            let families = agreement_families () in
            List.length families >= 5
            && List.for_all families ~f:(fun (_, code) ->
                   match
                     ( String.substr_index code ~pattern:"let checks",
                       String.substr_index code ~pattern:": agreement =" )
                   with
                   | Some at_checks, Some at_desc ->
                       at_desc < at_checks
                       &&
                       let tail = String.subo code ~pos:at_desc in
                       (not (String.is_substring tail ~substring:"\ntype "))
                       && not (String.is_substring tail ~substring:"\nlet load_")
                   | _ -> false)) }

(* The record's "declared at" and the overview's tooltip derive where an
   agreement is declared from this convention instead of storing it. The
   [: agreement] annotation is required: it is what makes the value
   findable as text. *)
let agreement_metadata_check : pure_test =
  { name = "agreements.metadata_is_declared_under_its_slug";
    holds = "Every agreement is declared as a value named after its slug and typed agreement, in the family file its registry row points to.";
    check =
      (fun () ->
        let module CR = Canary_agreement in
        match Sys_unix.file_exists agreement_dir with
        | `No | `Unknown -> true
        | `Yes ->
            let bad =
              List.filter_map CR.agreement_registry ~f:(fun r ->
                  let base =
                    Stdlib.Filename.basename (CR.family_file_of r.CR.ag_id)
                  in
                  let p = agreement_dir ^ "/" ^ base in
                  match Sys_unix.file_exists p with
                  | `Yes ->
                      let code = code_without_comments p in
                      let want =
                        "let " ^ r.CR.ag_slug ^ " : agreement ="
                      in
                      if String.is_substring code ~substring:want then None
                      else
                        Some
                          (Printf.sprintf "%s: no `%s` in %s" r.CR.ag_slug want
                             base)
                  | _ -> Some (Printf.sprintf "%s: %s is missing" r.CR.ag_slug p))
            in
            if not (List.is_empty bad) then
              List.iter bad ~f:(fun b -> Fmt.pr "    %s@." b);
            List.is_empty bad) }

(* The names fill the overview's `implemented at` column. A name is a
   string on its method, since an OCaml closure carries neither its own
   name nor its file; the file comes from the gathering list. *)
let agreement_impl_check : pure_test =
  { name = "agreements.impl_functions_exist";
    holds = "Every evaluator function an agreement names is defined in its family file, and every agreement with an evaluator names its function.";
    check =
      (fun () ->
        let module CR = Canary_agreement in
        match Sys_unix.file_exists agreement_dir with
        | `No | `Unknown -> true (* not run from the repo root *)
        | `Yes ->
            let source_of id =
              let f = CR.family_file_of id in
              let base = Stdlib.Filename.basename f in
              let p = agreement_dir ^ "/" ^ base in
              match Sys_unix.file_exists p with
              | `Yes -> Some (code_without_comments p)
              | _ -> None
            in
            let bad =
              List.concat_map CR.agreement_registry ~f:(fun r ->
                  let ms = r.CR.ag.Canary_agreement_common.ag_methods in
                  let named =
                    List.filter_map ms ~f:(fun m ->
                        m.Canary_agreement_common.m_impl)
                  in
                  let has_eval =
                    List.exists ms ~f:(fun m ->
                        Option.is_some m.Canary_agreement_common.m_eval)
                  in
                  let missing =
                    List.filter_map named ~f:(fun fn ->
                        match source_of r.CR.ag_id with
                        | None -> None
                        | Some code ->
                            if
                              String.is_substring code
                                ~substring:("let " ^ fn ^ " ")
                              || String.is_substring code
                                   ~substring:("let " ^ fn ^ "\n")
                            then None
                            else
                              Some
                                (Printf.sprintf "%s: no `let %s` in %s"
                                   r.CR.ag_slug fn (CR.family_file_of r.CR.ag_id)))
                  in
                  let unnamed =
                    if has_eval && List.is_empty named then
                      [ Printf.sprintf
                          "%s: has an evaluator but no ~impl — the overview \
                           would show it as unimplemented"
                          r.CR.ag_slug ]
                    else []
                  in
                  missing @ unnamed)
            in
            if not (List.is_empty bad) then
              List.iter bad ~f:(fun b -> Fmt.pr "    %s@." b);
            List.is_empty bad) }

(* The agreement layer's tiers are the common types, the families, and
   the registry that gathers them. Each exception is named here with its
   reason: canary_agreement_composed is not a family (it reads other
   families' verdicts), and a module may name a sibling in a comment. *)
let agreement_tiers_check : pure_test =
  { name = "agreements.families_do_not_reach_sideways";
    holds = "No agreement family names another family in its code, and a composing module names only the families it declares it composes.";
    check =
      (fun () ->
        let dir = agreement_dir in
        match Sys_unix.file_exists dir with
        | `No | `Unknown -> true (* not run from the repo root *)
        | `Yes ->
            let modules =
              Sys_unix.readdir dir |> Array.to_list
              |> List.filter ~f:(String.is_suffix ~suffix:".ml")
              |> List.map ~f:(fun f ->
                     let base = String.chop_suffix_exn f ~suffix:".ml" in
                     ( String.capitalize base,
                       code_without_comments (dir ^ "/" ^ f) ))
            in
            (* the property [agreement_families] keys on *)
            let is_family (_, code) =
              String.is_substring code ~substring:"let checks"
              && not (String.is_substring code ~substring:"let composes")
            in
            let families = List.filter modules ~f:is_family in
            let family_names = List.map families ~f:fst in
            List.length families >= 5
            && List.for_all families ~f:(fun (self, code) ->
                   List.for_all family_names ~f:(fun other ->
                       String.equal other self
                       || not (String.is_substring code ~substring:other)))
            (* a composing module names only the families it composes,
               and composes at least one *)
            && (not (List.is_empty Canary_agreement_composed.composes))
            && List.for_all
                 (List.filter modules ~f:(fun (_, code) ->
                      String.is_substring code ~substring:"let composes"))
                 ~f:(fun (_, code) ->
                   List.for_all family_names ~f:(fun other ->
                       (not (String.is_substring code ~substring:other))
                       || List.mem Canary_agreement_composed.composes other
                            ~equal:String.equal))) }

(* A family's claim holds for every language and mechanism; where its
   evidence lives is the owner module's fact. Literals are checked, not
   constructors: matching on [Ocaml_mli] reads evidence the family was
   handed. The typed stub belongs to cstubs, not OCaml: [external] is how
   cstubs spells the boundary, and an OCaml dynlink binding has none. *)
let surface_facts_check : pure_test =
  { name = "agreements.surface_facts_live_with_their_owner";
    holds = "No agreement family spells an evidence file name owned by a language or mechanism module, such as inspect_mli.";
    check =
      (fun () ->
        match Sys_unix.file_exists agreement_dir with
        | `No | `Unknown -> true
        | `Yes ->
            let owned =
              [ ("Canary_agreement_ocaml", [ "inspect_mli" ]);
                ( "Canary_agreement_cstubs",
                  [ "inspect_typed_binding_stub_ocaml" ] ) ]
            in
            let bad =
              List.concat_map (agreement_families ()) ~f:(fun (name, code) ->
                  List.concat_map owned ~f:(fun (owner, lits) ->
                      List.filter_map lits ~f:(fun lit ->
                          if String.is_substring code ~substring:lit then
                            Some
                              (Printf.sprintf "%s spells %s (owned by %s)" name
                                 lit owner)
                          else None)))
            in
            if not (List.is_empty bad) then
              Fmt.pr "    %s@." (String.concat ~sep:" | " bad);
            List.is_empty bad) }

(* The agreement docs agree with the code: the names they quote are
   live, their § references resolve, every agreement's anchor exists,
   every document a check reads exists, and the frame exclusions match
   the registry. *)
let agreement_doc_checks : pure_test list =
  let module CR = Canary_agreement in
  let model_doc = "doc/canary/design/agreement/README.md" in
  let components_doc = "doc/canary/design/agreement/components.md" in
  let agreement_docs = [ model_doc; components_doc ] in
  (* [None] for a missing file; agreements.read_docs_exist fails on that *)
  let read_doc p =
    if Stdlib.Sys.file_exists p then
      Some (Stdlib.In_channel.with_open_text p Stdlib.In_channel.input_all)
    else None
  in
  [ (* A snake_case name must be defined in src, not merely mentioned,
       since a comment in src may still name retired code. Fenced blocks
       are skipped: the docs quote shell and OCaml there that need not
       exist. *)
    { name = "agreements.doc_names_live_code";
      holds = "Every file, module and snake_case name quoted in the agreement docs outside code blocks is defined in src, unless listed as the docs' own vocabulary.";
      check =
        (fun () ->
          (* both docs as one text: which one quotes a name does not matter *)
          match List.filter_map agreement_docs ~f:read_doc with
          | [] -> true
          | texts ->
            let text = String.concat ~sep:"\n" texts in
            let rec walk dir acc =
              Sys_unix.readdir dir |> Array.to_list
              |> List.fold ~init:acc ~f:(fun acc e ->
                     let p = dir ^ "/" ^ e in
                     match Sys_unix.is_directory p with
                     | `Yes -> walk p acc
                     | _ ->
                         if String.is_suffix e ~suffix:".ml" then
                           (e, Stdio.In_channel.read_all p) :: acc
                         else acc)
            in
            let sources = walk "src" [] in
            let file_of base =
              List.find_map sources ~f:(fun (e, body) ->
                  if String.equal e base then Some body else None)
            in
            (* a definition or a literal, not a passing mention: [let x],
               [type x], a labelled argument, a string literal, or a
               record field, its colon any number of spaces away *)
            let defined_in body tok =
              List.exists
                [ "let " ^ tok; "type " ^ tok; "~" ^ tok; "\"" ^ tok ^ "\"" ]
                ~f:(fun pat -> String.is_substring body ~substring:pat)
              ||
              let n = String.length body and m = String.length tok in
              let rec go i =
                match String.substr_index body ~pos:i ~pattern:tok with
                | None -> false
                | Some at ->
                    let before_ok =
                      at = 0 || Char.is_whitespace body.[at - 1]
                    in
                    let rec skip k =
                      if k < n && Char.equal body.[k] ' ' then skip (k + 1) else k
                    in
                    let after = skip (at + m) in
                    if before_ok && after < n && Char.equal body.[after] ':' then
                      true
                    else go (at + 1)
              in
              go 0
            in
            let defined tok =
              List.exists sources ~f:(fun (_, body) -> defined_in body tok)
            in
            (* Names the docs mean as theory or as the world's own, not as
               src definitions: surface roles, proposed artifacts, an
               ncurses symbol, object-format and loader names, and hook
               moments ([<action>_post] composes an action with its post
               hook, so no such [let] exists). *)
            (* only snake_case names are checked, so only they need listing *)
            let doc_vocabulary =
              [ "native_header"; "binding_header"; "app_direct"; "app_via_helper"; "cur_term";
                "build_lib_post"; "install_lib_post"; "compatibility_version" ]
            in
            let backticked =
              let lines = String.split_lines text in
              let _, toks =
                List.fold lines ~init:(false, []) ~f:(fun (fenced, acc) line ->
                    if String.is_prefix (String.lstrip line) ~prefix:"```" then
                      (not fenced, acc)
                    else if fenced then (fenced, acc)
                    else
                      let rec go acc i =
                        match String.substr_index line ~pos:i ~pattern:"`" with
                        | None -> acc
                        | Some a -> (
                            match
                              String.substr_index line ~pos:(a + 1) ~pattern:"`"
                            with
                            | None -> acc
                            | Some b ->
                                go
                                  (String.sub line ~pos:(a + 1) ~len:(b - a - 1)
                                  :: acc)
                                  (b + 1))
                      in
                      (fenced, go acc 0))
              in
              List.dedup_and_sort toks ~compare:String.compare
            in
            let is_snake t =
              (not (String.is_empty t))
              && Char.is_lowercase t.[0]
              && String.exists t ~f:(Char.equal '_')
              && String.for_all t ~f:(fun ch ->
                     Char.is_lowercase ch || Char.is_digit ch || Char.equal ch '_')
            in
            let bad =
              List.filter backticked ~f:(fun t ->
                  (* metavariables and globs name a shape, not a
                     definition: canary_agreement_<topic>.ml,
                     canary_pm_*.ml *)
                  if
                    String.exists t ~f:(fun c ->
                        Char.equal c '*' || Char.equal c ' ' || Char.equal c '<'
                        || Char.equal c '>')
                  then false
                  else
                    let base =
                      Option.value (List.last (String.split t ~on:'/')) ~default:t
                    in
                    if String.is_suffix base ~suffix:".ml" then
                      String.length base > 3 && Option.is_none (file_of base)
                    else if String.is_prefix t ~prefix:"Canary_" then
                      let m, member =
                        match String.lsplit2 t ~on:'.' with
                        | Some (m, mem) -> (m, Some mem)
                        | None -> (t, None)
                      in
                      match file_of (String.lowercase m ^ ".ml") with
                      | None -> true
                      | Some body -> (
                          match member with
                          | None -> false
                          | Some mem -> not (String.is_substring body ~substring:mem))
                    else
                      is_snake t
                      && (not (List.mem doc_vocabulary t ~equal:String.equal))
                      && not (defined t))
            in
            if not (List.is_empty bad) then
              Fmt.pr
                "    doc names code that has no definition: %s@."
                (String.concat ~sep:", " bad);
            List.is_empty bad) };
    (* A line naming another .md cites that document's sections. *)
    { name = "agreements.doc_cross_refs_resolve";
      holds = "Every section reference in an agreement doc resolves to a heading in that doc, except on lines that name another document.";
      check =
        (fun () ->
          List.for_all agreement_docs ~f:(fun doc ->
          match read_doc doc with
          | None -> true
          | Some text ->
            let lines = String.split_lines text in
            let take_tok s =
              let n = String.length s in
              let rec go i =
                if i >= n then i
                else
                  let ch = s.[i] in
                  if Char.is_alphanum ch || Char.equal ch '.' then go (i + 1)
                  else i
              in
              String.sub s ~pos:0 ~len:(go 0)
            in
            let headings =
              List.filter_map lines ~f:(fun l ->
                  if String.is_prefix l ~prefix:"#" then
                    let body =
                      String.lstrip (String.lstrip l ~drop:(Char.equal '#'))
                    in
                    let tok = take_tok body in
                    let tok = String.rstrip tok ~drop:(Char.equal '.') in
                    if String.is_empty tok then None else Some tok
                  else None)
              |> List.dedup_and_sort ~compare:String.compare
            in
            let refs_of line =
              let rec go acc i =
                match String.substr_index line ~pos:i ~pattern:"\xc2\xa7" with
                | None -> acc
                | Some j ->
                    let start = j + 2 in
                    let tok = take_tok (String.drop_prefix line start) in
                    let tok = String.rstrip tok ~drop:(Char.equal '.') in
                    go (if String.is_empty tok then acc else tok :: acc)
                      (start + 1)
              in
              go [] 0
            in
            let bad =
              List.concat_map lines ~f:(fun l ->
                  if String.is_substring l ~substring:".md" then []
                  else
                    List.filter (refs_of l) ~f:(fun r ->
                        not
                          (List.mem headings r ~equal:String.equal
                          || List.exists headings ~f:(fun h ->
                                 String.is_prefix h ~prefix:(r ^ ".")))))
              |> List.dedup_and_sort ~compare:String.compare
            in
            if not (List.is_empty bad) then
              Fmt.pr "    unresolved doc refs in %s: %s@." doc
                (String.concat ~sep:", " (List.map bad ~f:(fun r -> "\xc2\xa7" ^ r)));
            List.is_empty bad)) };
    (* A check that cannot find its document passes, as it must outside
       the repo root, so a renamed or deleted document fails here
       instead; removing one is a deliberate edit to this list. Not
       checked: that the docs keep no hand-written catalogue, which is a
       reading job. *)
    { name = "agreements.read_docs_exist";
      holds = "Every document the tests and harness checks read exists, so none of them can pass on a missing input.";
      check =
        (fun () ->
          match Sys_unix.file_exists "doc/canary/design/agreement" with
          | `No | `Unknown -> true (* not run from the repo root *)
          | `Yes ->
              let required =
                [ "doc/canary/design/agreement/README.md";
                  "doc/canary/design/agreement/components.md";
                  "doc/canary/design/matrix.md" ]
              in
              let missing =
                List.filter required ~f:(fun p ->
                    not (Stdlib.Sys.file_exists p))
              in
              if not (List.is_empty missing) then
                Fmt.pr
                  "    doc(s) a check reads are gone — the checks that read \
                   them now pass vacuously: %s@."
                  (String.concat ~sep:", " missing);
              List.is_empty missing) };
    (* [prop_frame] says in code why a proposal has no row, and the
       agreement README's §8 and §8.1 say it in prose. The catalogue's
       out-of-the-table section renders [prop_frame], so the two must not
       drift. *)
    { name = "agreements.theory_names_the_frame_exclusions";
      holds = "The proposals the registry excludes, as outside the frame or as not agreements, are exactly those the agreement README names in its matching exclusion section.";
      check =
        (fun () ->
          match read_doc model_doc with
          | None -> true
          | Some text ->
              let section ~from ~upto =
                match String.substr_index text ~pattern:from with
                | None -> None
                | Some i ->
                    let rest = String.subo text ~pos:(i + String.length from) in
                    Some
                      (match String.substr_index rest ~pattern:upto with
                       | Some j -> String.sub rest ~pos:0 ~len:j
                       | None -> rest)
              in
              let s7 = section ~from:"## 8. What this does not explain"
                         ~upto:"### 8.1" in
              let s71 = section ~from:"### 8.1" ~upto:"\n## " in
              let bad =
                List.concat_map CR.proposed_agreements ~f:(fun p ->
                    let want, where =
                      match p.CR.prop_frame with
                      | CR.Outside_the_frame _ -> (Some s7, "§8")
                      | CR.Not_an_agreement _ -> (Some s71, "§8.1")
                      | CR.In_frame | CR.Unfiled _ -> (None, "")
                    in
                    let named_in sec =
                      match sec with
                      | None -> false
                      | Some t -> String.is_substring t ~substring:p.CR.prop_slug
                    in
                    match want with
                    | Some sec ->
                        if named_in (Some (Option.value sec ~default:"")) then []
                        else
                          [ Printf.sprintf
                              "%s is classified out-of-frame but README.md %s \
                               does not name it"
                              p.CR.prop_slug where ]
                    | None ->
                        (* the converse: the README must not name it *)
                        List.filter_map
                          [ (s7, "§8"); (s71, "§8.1") ]
                          ~f:(fun (sec, w) ->
                            if named_in (Some (Option.value sec ~default:"")) then
                              Some
                                (Printf.sprintf
                                   "README.md %s names %s, but the registry \
                                    does not classify it as excluded"
                                   w p.CR.prop_slug)
                            else None))
              in
              (* the sections must exist, so a renamed heading fails *)
              let bad =
                match (s7, s71) with
                | Some _, Some _ -> bad
                | _ -> "README.md: §8 or §8.1 heading not found" :: bad
              in
              if not (List.is_empty bad) then
                List.iter bad ~f:(fun b -> Fmt.pr "    %s@." b);
              List.is_empty bad) };
    { name = "agreements.doc_anchors_exist";
      holds = "Every agreement's doc anchor names a section heading that exists in the components doc.";
      check =
        (fun () ->
          (* components.md alone: an anchor names the component section
             that explains why the agreement exists *)
          match read_doc components_doc with
          | None -> true (* not in a checkout *)
          | Some text ->
            List.for_all CR.all_agreements ~f:(fun e ->
                (* "§6.3" resolves if the doc has a §6 or §6.3 heading *)
                let num =
                  String.chop_prefix e.CR.e_doc ~prefix:"\xc2\xa7"
                  |> Option.value ~default:e.CR.e_doc
                in
                let top =
                  match String.lsplit2 num ~on:'.' with
                  | Some (t, _) -> t
                  | None -> num
                in
                String.is_substring text ~substring:("# " ^ num ^ ".")
                || String.is_substring text ~substring:("## " ^ num ^ " ")
                || String.is_substring text ~substring:("## " ^ num ^ ".")
                || String.is_substring text ~substring:("# " ^ top ^ ".")) ) } ]

let one_escaper_check : Canary_project_test.pure_test =
  { name = "overview.one_escaper";
    holds = "Every overview module that defines esc binds it to the one shared escaper, which escapes quotes.";
    check =
      (fun () ->
        let dir = "src/canary/main" in
        let writers =
          Stdlib.Sys.readdir dir |> Array.to_list
          |> List.filter ~f:(fun f ->
                 String.is_suffix f ~suffix:".ml"
                 && (String.is_prefix f ~prefix:"canary_overview_"
                    || String.equal f "canary_agreement_overview.ml")
                 && not (String.equal f "canary_overview_assets.ml"))
        in
        List.length writers > 5
        && List.for_all writers ~f:(fun f ->
               let src =
                 Stdlib.In_channel.with_open_bin (Stdlib.Filename.concat dir f)
                   Stdlib.In_channel.input_all
               in
               List.for_all (String.substr_index_all src ~may_overlap:false ~pattern:"let esc")
                 ~f:(fun i ->
                   String.is_substring_at src ~pos:i ~substring:"let esc = Canary_overview_assets.esc"))
        && String.is_substring (Canary_overview_assets.esc {|a"b|}) ~substring:"&quot;")
  }

(* Figure 1's boxes name tests, so a name written only in this file does
   not count. *)
let flow_names_check : Canary_project_test.pure_test =
  { name = "harness.flow_names_exist";
    holds = "Every test a box of Figure 1 names is written in the test sources, every make target it names is in the Makefile, and every module §0 names has a source file.";
    check =
      (fun () ->
        let module F = Canary_overview_flow in
        let tests_src =
          String.concat
            (List.map
               (Canary_test_fixtures.test_sources ()
               @ [ "src/canary/main/canary_tests.ml"; "src/canary/test/canary_artifact_test.ml";
                   "src/canary/test/canary_pm_test.ml" ])
               ~f:(fun p -> Stdlib.In_channel.with_open_bin p Stdlib.In_channel.input_all))
        in
        let makefile = Stdlib.In_channel.with_open_bin "Makefile" Stdlib.In_channel.input_all in
        let held_ok =
          List.for_all F.boxes ~f:(fun b ->
              List.for_all b.F.bx_held ~f:(fun h ->
                  match String.chop_prefix h ~prefix:"make " with
                  | Some target -> String.is_substring makefile ~substring:("\n" ^ target ^ ":")
                  | None -> String.is_substring tests_src ~substring:(Printf.sprintf {|"%s"|} h)))
        in
        let modules =
          List.concat_map F.sections ~f:(fun s -> s.F.sc_code)
          @ List.concat_map F.subjects ~f:(fun s ->
                List.filter s.F.sj_code.F.ly_from ~f:(String.is_prefix ~prefix:"Canary_"))
        in
        let has_source m =
          List.exists
            [ "base"; "agreement"; "tool"; "action"; "backend"; "project"; "main"; "test" ]
            ~f:(fun d ->
              Stdlib.Sys.file_exists
                (Printf.sprintf "src/canary/%s/%s.ml" d (String.lowercase m)))
        in
        held_ok && List.for_all modules ~f:has_source)
  }

let layout_rules_explained_check : Canary_project_test.pure_test =
  { name = "harness.layout_rules_are_explained";
    holds = "Every layout rule says what it holds and why, and every rule a test holds names a registered test.";
    check =
      (fun () ->
        let module P = Canary_overview_looks in
        List.for_all P.layout_rules ~f:(fun r ->
            (not (String.is_empty r.P.lr_says))
            && (not (String.is_empty r.P.lr_why))
            &&
            match r.P.lr_check with
            | P.Places _ -> true
            | P.Tested_by name ->
                List.exists base_tests ~f:(fun t -> String.equal t.Canary_project_test.name name)))
  }

(* The bridge record's kind is the exception: it describes packages, not
   artifacts. *)
let runs_reads_no_kind_check : pure_test =
  { name = "harness.runs_module_reads_no_artifact_kind";
    holds = "Canary_overview_runs names no artifact kind of its own, so Canary_matrix stays the one reader of an inspection.";
    check =
      (fun () ->
        let code = code_without_comments "src/canary/main/canary_overview_runs.ml" in
        List.for_all [ {|"native"|}; {|"c_stub"|}; {|"ocaml"|}; {|"ocaml_mli"|}; {|"python"|} ]
          ~f:(fun k -> not (String.is_substring code ~substring:k)))
  }

let repo_checks : pure_test list =
  [ tool_routing_ratchet_check; agreement_module_shape_check; agreement_metadata_check;
    agreement_impl_check; agreement_tiers_check; surface_facts_check ]
  @ agreement_doc_checks
  @ [ one_escaper_check; flow_names_check; layout_rules_explained_check; runs_reads_no_kind_check ]

(* The checks on the lists themselves read the list they are on, hence
   [rec]. *)
let rec self_checks : pure_test list = [ registration_check; holds_said_check ]

(* Reads every record whose name is a literal, in the test sources and
   in this file. Both ways of opening such a record must be found, so the
   check cannot pass by finding nothing. *)
and registration_check : pure_test =
  { name = "harness.every_written_check_runs";
    holds = "Every test and harness check written in the sources is registered, so it runs.";
    check =
      (fun () ->
        let registered =
          List.map
            (Canary_project_test.all_tests @ Canary_tests.tests @ repo_checks @ self_checks)
            ~f:(fun t -> t.Canary_project_test.name)
        in
        let written opening src =
          List.filter_map (String.substr_index_all src ~may_overlap:false ~pattern:opening)
            ~f:(fun i ->
              let from = i + String.length opening in
              Option.bind (String.index_from src from '"') ~f:(fun stop ->
                  let after =
                    String.lstrip
                      (String.sub src ~pos:(stop + 1)
                         ~len:(Int.min 64 (String.length src - stop - 1)))
                  in
                  let next = String.lstrip (String.drop_prefix after 1) in
                  if
                    String.is_prefix after ~prefix:";"
                    && (String.is_prefix next ~prefix:"holds" || String.is_prefix next ~prefix:"check")
                  then Some (String.sub src ~pos:from ~len:(stop - from))
                  else None))
        in
        let sources =
          List.map (Canary_test_fixtures.test_sources () @ [ "harness/harness.ml" ]) ~f:(fun p ->
              Stdlib.In_channel.with_open_bin p Stdlib.In_channel.input_all)
        in
        let found =
          List.map [ {|{ name = "|}; {|{ Canary_project_test.name = "|} ] ~f:(fun opening ->
              List.concat_map sources ~f:(written opening))
        in
        let unrun =
          List.filter (List.concat found) ~f:(fun n ->
              not (List.mem registered n ~equal:String.equal))
        in
        List.iter unrun ~f:(Fmt.pr "    written, never run: %s@.");
        List.for_all found ~f:(Fn.non List.is_empty) && List.is_empty unrun)
  }

(* The page lists the sentence for each test, so it is one line, ends as
   a sentence and fits a table cell; a harness check's follows suit. *)
and holds_said_check : pure_test =
  { name = "harness.every_check_says_what_it_holds";
    holds = "Every test and harness check states the claim it holds in one sentence.";
    check =
      (fun () ->
        let bad =
          List.filter
            (List.concat_map (files ()) ~f:(fun (_, _, ts) -> ts) @ repo_checks @ self_checks)
            ~f:(fun t ->
              let h = t.Canary_project_test.holds in
              String.is_empty h || String.contains h '\n'
              || (not (String.is_suffix h ~suffix:"."))
              || String.length h > 200)
        in
        List.iter bad ~f:(fun t ->
            Fmt.pr "    %s holds %S@." t.Canary_project_test.name t.Canary_project_test.holds);
        List.is_empty bad)
  }

let checks : pure_test list = repo_checks @ self_checks

let () =
  let results = List.map checks ~f:(fun t -> (t, run_pure_test t)) in
  List.iter results ~f:(fun (t, ok) -> Fmt.pr "[%s] %s@." (if ok then "PASS" else "FAIL") t.name);
  let passed = List.count results ~f:snd in
  Fmt.pr "Harness: %d/%d passed.@." passed (List.length results);
  if passed < List.length results then Stdlib.exit 1

(** The agents' harness: checks of the repository's own text. The
    documents name live code and their references resolve, modules keep
    their declared shape, the ratchets hold, and every test and harness
    check is registered and says what it holds. Canary never runs these;
    the agent does, with [make harness], before committing. *)

open Base
open Canary_project_test
open Canary_tests

(* The agreement layer's source, with comments removed — nesting
   tracked rather than guessed per line, because prose may name a
   sibling module while code may not. Shared by the two pins that read
   these files. *)
let agreement_dir = "src/canary/agreement"

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

(** The families, as (module name, comment-free source). A FAMILY is a
    module that publishes [checks] and declares no [composes] — a
    PROPERTY, not a filename convention, so renaming the files cannot
    empty the pins that read this (2026-09-02). *)
let agreement_families () : (string * string) list =
  Sys_unix.readdir agreement_dir |> Array.to_list
  |> List.filter ~f:(String.is_suffix ~suffix:".ml")
  |> List.map ~f:(fun f ->
         ( String.capitalize (String.chop_suffix_exn f ~suffix:".ml"),
           code_without_comments (agreement_dir ^ "/" ^ f) ))
  |> List.filter ~f:(fun (_, code) ->
         String.is_substring code ~substring:"let checks"
         && not (String.is_substring code ~substring:"let composes"))

(* ── Tool-routing RATCHET (user, 2026-08-05) ──
   Raw verbs spreading through the specs are exactly the code scattering
   TODO #18 fights. The baseline below freezes TODAY's per-file line
   counts; a count ABOVE baseline fails the suite (route the new use
   through a tool/ primitive instead); a count below baseline means
   cleanup happened — lower the baseline in the same commit. Comments
   count too (crude by design: a ratchet, not a parser). *)
let tool_routing_ratchet_test : pure_test =
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
      (* verb → per-file baseline (absent file = 0 allowed) *)
      (* Burn-down log: sqlite's gcc/curl/unzip/nm went to ZERO 2026-08-05
         (routed via curl_unzip_cmd / cc_shared_lib_cmd /
         native_lib_probe_cmd). Next candidates: llvm's pip-install chain
         (needs a pip_install_any primitive with the uv fallback) and the
         opam-install raws (A9-step-2 territory). *)
      let baseline =
        [ ("cmake ",
           [ (* +1 vs the old 6 = the C2 cmake-source COMMENT (the
                realize-time probe misdiagnosis); the shell goes through
                cmake_configure_cmd *)
             ("canary_project_llvm.ml", 7); ("canary_tiny_scenario.ml", 4);
             (* 7 -> 8 (2026-08-19): both extras are COMMENTS — cmake's
                default generator, and the install-prefix isolation note
                naming the staging verb. The shell goes through
                cmake_configure_cmd / cmake_install_cmd.
                8 -> 7 (2026-09-15): the file has been at 7 for a while
                and nobody lowered it — the ratchet only fails ABOVE
                baseline, so drift in this direction is silent. Tightened
                on the way past. *)
             ("canary_project_z3.ml", 7); ("canary_run.ml", 1) ]);
          ("ninja ",
           [ (* one COMMENT mention (the -G Ninja note above).
                1 -> 2 (2026-09-15): a second COMMENT, on the
                published-package probe, saying that the local recipe
                skips cmake+ninja when canary already built the binding
                — which is why probing the package costs a compile and
                not a second z3 build. Evidence, not shell. *)
             ("canary_project_z3.ml", 2);
             (* one COMMENT mention (the ninja LLVM dylib note, 2026-08-13) *)
             ("canary_project_llvm.ml", 1) ]);
          ("gcc ", []);
          ("curl ", []);
          (* "unzip -" (flag form): the bare word also appears in the tool
             primitive's NAME (curl_unzip_cmd), which is exactly the
             routing we want — only raw invocations should count. *)
          ("unzip -", []);
          ("pip install", [ ("canary_project_llvm.ml", 3) ]);
          ("opam install",
           [ ("canary_opam_binding.ml", 1);
             (* all 3 occurrences are COMMENTS describing the routed verb —
                the shell goes through [SB.fetch_binding_cmd] *)
             ("canary_project_ssl.ml", 3);
             ("canary_project_llvm.ml", 1);
             (* 3 -> 2 (2026-08-17): the conf-* refactor removed one
                mention — the shell goes through [SB.fetch_binding_cmd].
                2 -> 3 (2026-09-15): a COMMENT naming the publish this
                world runs, on the probe that finally consumes the
                package it makes. Quoting the command is the point of
                that comment — it says WHICH package the probe is
                asking ocamlfind for — and the shell still goes through
                [SB.fetch_binding_cmd] / the pack row. *)
             ("canary_project_z3.ml", 3);
             (* all 5 are COMMENTS quoting the opam commands that were
                MEASURED while landing torch (the dry-runs that establish
                the one-point binding axis and the solver-enforced gate) —
                evidence, not shell. The lib fetch goes through
                [Canary_pm_opam.install_cmd], the binding through
                [SB.fetch_binding_cmd]. *)
             ("canary_project_torch.ml", 5) ]);
          ("nm -D",
           [ ("canary_tiny_workspace.ml", 2);
             ("canary_tiny_scenario.ml", 1) ]);
          ("git clone", []);
          (* one COMMENT mention (the gmp 6.2.1 Tarball remote, C2.5) —
             the fetch goes through the Tar remote machinery *)
          ("tar ", [ ("canary_project_zarith.ml", 1) ]) ]
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

(* Five modules had four different orders before this pin. The pin
   states the two boundaries that carry the meaning — [checks] before
   any description, and no evidence or type declared after the
   descriptions start — rather than the exact banners, so the shape is
   enforced without freezing the prose. *)
let agreement_module_shape_pin : pure_test =
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
                       (* the agreements' declarations come FIRST and the
                          [checks] list that gathers them LAST — the
                          order flipped on 2026-09-12, because a family
                          now publishes [(agreement_id * agreement) list]
                          and cannot name a value it has not defined *)
                       at_desc < at_checks
                       &&
                       (* … and no evidence or type is declared after the
                          agreements start *)
                       let tail = String.subo code ~pos:at_desc in
                       (not (String.is_substring tail ~substring:"\ntype "))
                       && not (String.is_substring tail ~substring:"\nlet load_")
                   | _ -> false)) }

(* `implemented at` tracks the EVALUATOR — the function that compares
   evidence. It says nothing about where the agreement's metadata lives:
   its kind, subject, claim, rooting, slot, fault tag and method list.
   That metadata is code as much as the evaluator is, and a reader who
   wants to know why a row says `pairing` has to find the record.

   It does NOT need a field, because it is already derivable: every
   agreement is bound to a value named exactly its slug, in the family
   file the gathering list names. `soname_matches_requirement` is
   `let soname_matches_requirement : agreement =` in
   `canary_agreement_identity.ml`. Deriving beats declaring — a field
   would be a second place to get it wrong — but a derivation is only
   safe while the convention holds, and nothing was enforcing it.

   So this pins the convention rather than adding the field. It is what
   lets the record print "declared at" and the overview's tooltip name
   the declaration, both without storing anything.

   The binding must be `: agreement` explicitly. That is not pedantry:
   the type annotation is what makes the value greppable at all, and
   every one of the thirteen already carries it. *)
let agreement_metadata_pin : pure_test =
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

(* The overview's `implemented at` column is half derived and half
   written down, and only the derived half is safe. The FILE comes from
   the gathering list, so it cannot drift. The FUNCTION is a string on
   the method, because an OCaml closure carries neither its own name nor
   its file — and a string beside code is exactly the thing that rots.

   So the pin holds BOTH directions, and the second one is the one that
   matters:

   (a) a named function EXISTS in the file the gathering points at. A
       rename that forgets the label turns the column into a lie that
       still renders black;
   (b) an agreement that HAS an evaluator NAMES it. Without this the
       column fails the safe way — a landed agreement quietly rendering
       a red "no evaluator yet" cell — and a red cell nobody believes is
       worse than no column, because the three genuinely unimplemented
       ones are the whole point of the colour. *)
let agreement_impl_pin : pure_test =
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
                  (* (a) each named function is defined in that file *)
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
                  (* (b) an implemented agreement says where it is *)
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

(* The THREE TIERS of the agreement layer (2026-09-02, user): a common
   module declares the types; each canary_agreement_<topic> is one concrete
   family and refers only to that; the registry gathers them and
   provides the matrix. The load-bearing half is the middle one — a
   family must not reach sideways — so this reads the sources and
   fails if one names another, which is how the tiers stay true after
   the next check lands.

   Two deliberate exceptions, both named here so that adding a third
   requires saying why: canary_agreement_composed is not a family (it reads
   other families' VERDICTS, which is the whole point of it), and a
   module may MENTION a sibling in prose. *)
let agreement_tiers_pin : pure_test =
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
            (* A FAMILY is a module that publishes [checks] and does not
               declare what it [composes] — a PROPERTY, not a filename
               convention (2026-09-02). The prefix used to be the
               marker, which made renaming the files a way to empty this
               pin silently; keying on the property means the rename
               cannot go dark. *)
            let is_family (_, code) =
              String.is_substring code ~substring:"let checks"
              && not (String.is_substring code ~substring:"let composes")
            in
            let families = List.filter modules ~f:is_family in
            let family_names = List.map families ~f:fst in
            List.length families >= 5
            (* a family names no other family in code *)
            && List.for_all families ~f:(fun (self, code) ->
                   List.for_all family_names ~f:(fun other ->
                       String.equal other self
                       || not (String.is_substring code ~substring:other)))
            (* the composition names exactly what it declares it
               composes, and it declares at least one *)
            && (not (List.is_empty Canary_agreement_composed.composes))
            && List.for_all
                 (List.filter modules ~f:(fun (_, code) ->
                      String.is_substring code ~substring:"let composes"))
                 ~f:(fun (_, code) ->
                   List.for_all family_names ~f:(fun other ->
                       (not (String.is_substring code ~substring:other))
                       || List.mem Canary_agreement_composed.composes other
                            ~equal:String.equal))) }

(* The families state CLAIMS, which are neither language- nor
   mechanism-specific: c2 says the same sentence for OCaml and for
   Python and only the surface differs. So a family that spells one of
   these paths has taken a fact that is not its own.

   The literals, not the ADT constructors: a family legitimately
   MATCHES on [Ocaml_mli] in its predict — that is reading evidence it
   was handed. What it may not do is decide where that evidence lives.

   The owner column is the point. [inspect_typed_binding_stub_ocaml]
   reads like a language fact and is not one: [external] is how CSTUBS
   spells the boundary, and an OCaml dynlink binding has none. Getting
   that wrong is what this pin is for. The list grows one entry per
   module as they land. *)
let surface_facts_pin : pure_test =
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

let agreement_doc_checks : pure_test list =
  let module CR = Canary_agreement in
  (* TWO FILES since 2026-09-17, when `registry.md` split. [model.md] is
     the model and the integration; [components.md] is the per-component
     walk and the target of every [ag_doc] anchor. The pins that read
     "the doc" now say which half they mean, because they mean
     different halves: names may appear in either, § cross-references
     resolve WITHIN a file, and the anchors resolve only in the walk. *)
  (* THE MODEL MOVED TO README.md (2026-09-17), when `agreements.md`
     was deleted and the overview became THE reference. These two pins
     read a LIST, and `read_doc` answers [None] for a missing file, so
     pointing at the deleted file did not fail them — it just stopped
     them checking half of what they used to. `agreements.pinned_docs_exist`
     is the guard that makes that loud next time. *)
  (* two documents since 2026-09-30: the README took theory.md as its
     §5–§8, components.md took mechanism.md as its §3.3–§3.6 *)
  let model_doc = "doc/canary/design/agreement/README.md" in
  let components_doc = "doc/canary/design/agreement/components.md" in
  let agreement_docs = [ model_doc; components_doc ] in
  let read_doc p =
    if Stdlib.Sys.file_exists p then
      Some (Stdlib.In_channel.with_open_text p Stdlib.In_channel.input_all)
    else None
  in
  [ (* The two pins below check the doc's § anchors, which is why six
       commits of renaming left them green while the doc went on naming
       canary_agreement_run.ml (retired), contract_registry (the
       registry's old name), ag_role (a field removed with the legacy
       axis) and predicted_*_v2 (renamed).

       Two things it does NOT do, both deliberate. It checks for a
       DEFINITION rather than a mention, because three source comments
       still name Canary_agreement_run and a grep would have called the
       doc correct on their strength. And it skips fenced blocks, where
       the doc quotes shell and OCaml that is not required to exist. *)
    { name = "agreements.doc_names_live_code";
      holds = "Every file, module and snake_case name quoted in the agreement docs outside code blocks is defined in src, unless listed as the docs' own vocabulary.";
      check =
        (fun () ->
          (* BOTH halves: a code name may be introduced in either, and
             the question — does this identifier exist in src? — does
             not care which file said it *)
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
               record field (whose colon may sit any number of spaces
               away, which the first version of this got wrong) *)
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
            (* Names from the THEORY or the world, not from our code:
               two surface roles, two proposed artifacts, and an
               ncurses symbol from the §5.3 finding. A new entry here
               is a deliberate statement that the doc means something
               other than a definition in src/. *)
            let doc_vocabulary =
              [ "native_header"; "binding_header"; "app_direct";
                "app_via_helper"; "cur_term";
                (* ELF and Mach-O vocabulary (§6.3.4, 2026-09-09): these
                   are the object formats' own names, not ours. The doc
                   has to spell them to say what NEEDED is and how
                   Mach-O differs. *)
                "DT_NEEDED"; "DT_SONAME"; "DT_RPATH"; "DT_RUNPATH";
                (* HOOK MOMENTS, not definitions (2026-09-17). The
                   generated rooting table spells an action's post hook
                   as `<action>_post`, which is a composed name: the
                   action is a constructor and `_post` is the moment, so
                   no `let build_lib_post` exists or should. They became
                   visible when the catalogue was merged into
                   `agreements.md` and this pin began scanning generated
                   content — new coverage, not a new defect. *)
                "build_lib_post"; "install_lib_post";
                "LC_LOAD_DYLIB"; "LC_ID_DYLIB"; "LC_RPATH";
                "compatibility_version"; "@loader_path";
                "@executable_path"; "LD_LIBRARY_PATH"; "--as-needed";
                "/etc/ld.so.cache"; "dlopen" ]
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
                  (* metavariables and globs name a SHAPE, not a
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
    (* Lines mentioning another .md are skipped (their § belongs to that
       document, not this one). *)
    { name = "agreements.doc_cross_refs_resolve";
      holds = "Every section reference in an agreement doc resolves to a heading in that doc, except on lines that name another document.";
      check =
        (fun () ->
          (* PER FILE: headings are a property of one document, so a §
             reference resolves within the file that wrote it. A line
             naming another `.md` is exempt — that is how the split's
             cross-file references (model.md → components.md §5.5) stay
             legal. *)
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
    (* A PIN WHOSE INPUT VANISHED PASSES SILENTLY (2026-09-17).

       This replaces `agreements.catalogue_doc_is_generated`, which
       compared a generated region in `agreements.md` against the
       registry. That file was deleted when the overview became THE
       reference and the docs stopped carrying a catalogue — a good
       change — and the pin did not fail. It began with

           if not (Sys.file_exists path) then true

       which is the right answer for "not run from the repo root" and
       the wrong one for "the document is gone", and nothing can tell
       those apart from inside the check. Two more pins went quiet the
       same way: `doc_names_live_code` and `doc_cross_refs_resolve` read
       a LIST of docs through `read_doc`, which returns [None] for a
       missing file, so they silently halved their coverage.

       So the guard is one level up: every document a pin reads must
       EXIST. It fails loudly when a doc is renamed or deleted, which is
       exactly the moment the pins that read it stop meaning anything —
       and it is cheap, because the list is the pins' own. Removing a
       doc is then a deliberate edit here rather than a silent loss.

       Not pinned, and worth saying: that the docs carry no hand
       catalogue. `README.md` states the rule ("We do not maintain
       another catalogue or status list in these docs") and it is not
       mechanically checkable — a table listing agreements is forbidden
       when it restates status and fine when it adds an axis the
       overview lacks, as components.md §3.4's static-provider table does.
       That one is a reading job. *)
    { name = "agreements.pinned_docs_exist";
      holds = "Every document the pins read exists, so none of those pins can pass on a missing input.";
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
                  "    doc(s) a pin reads are gone — the pins that read \
                   them now pass vacuously: %s@."
                  (String.concat ~sep:", " missing);
              List.is_empty missing) };
    (* `prop_frame` says why a proposal has no row; the agreement
       README's §8 and §8.1 (theory.md's §7 and §7.1 until the
       2026-09-30 merge) say the same thing in prose, and they were
       written months apart. If one grows an exclusion the other does not, the
       catalogue's "Out of the table" grouping becomes a second opinion
       rather than a rendering of the model — which is the whole defect
       the grouping was added to fix.

       Directional on purpose: a proposal classified as excluded must be
       NAMED in the matching theory section, AND a proposal named there
       must carry the matching constructor. Either half alone lets the
       two drift apart in one direction. *)
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
                        (* the converse: theory must not claim it *)
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
              (* and the sections must exist at all *)
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
          (* components.md ALONE: an [ag_doc] anchor names the section
             that explains why the agreement exists, and those sections
             are the component walk. Pointing this at the model would
             pass vacuously — the model has a §1 and a §2 and nothing
             the anchors name. *)
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

let one_escaper_pin : Canary_project_test.pure_test =
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

(* The names §0 gives are real. Figure 1's boxes name tests, so a name
   must be written in a test source, not a harness one. *)
let flow_names_pin : Canary_project_test.pure_test =
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

(* A rule a test holds names it, so the list cannot point at a renamed
   check; defined after [base_tests] for that reason. *)
let layout_rules_explained_pin : Canary_project_test.pure_test =
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
            | P.Pinned_by name ->
                List.exists base_tests ~f:(fun t -> String.equal t.Canary_project_test.name name)))
  }

(* Only the bridge record's kind may appear there: it describes packages,
   not artifacts. *)
let runs_reads_no_kind_pin : pure_test =
  { name = "harness.runs_module_reads_no_artifact_kind";
    holds = "Canary_overview_runs names no artifact kind of its own, so Canary_matrix stays the one reader of an inspection.";
    check =
      (fun () ->
        let code = code_without_comments "src/canary/main/canary_overview_runs.ml" in
        List.for_all [ {|"native"|}; {|"c_stub"|}; {|"ocaml"|}; {|"ocaml_mli"|}; {|"python"|} ]
          ~f:(fun k -> not (String.is_substring code ~substring:k)))
  }

let repo_checks : pure_test list =
  [ tool_routing_ratchet_test; agreement_module_shape_pin; agreement_metadata_pin;
    agreement_impl_pin; agreement_tiers_pin; surface_facts_pin ]
  @ agreement_doc_checks
  @ [ one_escaper_pin; flow_names_pin; layout_rules_explained_pin; runs_reads_no_kind_pin ]

(* The checks on the lists themselves read the list they are on, hence
   [rec]. *)
let rec self_checks : pure_test list = [ written_checks_run_pin; holds_said_pin ]

(* A test or harness check left out of its list compiles and never runs.
   The scan reads every record whose name is a literal, in the test
   sources and in this file; both ways of opening such a record must be
   found somewhere, so it cannot pass by finding nothing. *)
and written_checks_run_pin : pure_test =
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

(* The sentence is what the page lists for a test, so it is one line,
   ends as a sentence and fits a table cell; a harness check's reads the
   same way. *)
and holds_said_pin : pure_test =
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

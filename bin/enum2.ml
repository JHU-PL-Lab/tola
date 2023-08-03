open Langs.Short

let usage_msg = "enum -l <N> -d <N>"
let id_size = ref 0
let lang_size = ref 0
let anon_fun _ = ()

let dump () =
  Short_id.dump_domain ();
  Short_lang.dump_domain ()

let cmdline () =
  Arg.parse
    [
      ("-l", Arg.Set_int lang_size, "Lang size");
      ("-d", Arg.Set_int id_size, "Id size");
    ]
    anon_fun usage_msg

let () = cmdline ()
(* ;
   dump () *)

(* let rec loop d fvs bvs : t list =
        let group_var = List.map (fun x -> Var x) bvs in
        if d <= 1 then group_var
        else
          let group_lam : t list =
            if List.length fvs > 0 then
              let bv = List.hd fvs in
              let f_bodies = loop (d - 1) (List.tl fvs) (bvs @ [ bv ]) in
              List.map (fun e -> Lam (bv, e)) f_bodies
            else []
          in
          let group_app : t list =
            let two_parts = Std.list_split fvs in
            List.concat_map
              (fun (fvs1, fvs2) ->
                let es1 : t list = loop (d - 1) fvs1 bvs in
                let es2 : t list = loop (d - 1) fvs2 bvs in
                List.concat_map
                  (fun e2 -> List.map (fun e1 -> App (e1, e2)) es1)
                  es2)
              two_parts
          in
          group_var @ group_lam @ group_app
      in
      loop max_depth Id.domain [] *)

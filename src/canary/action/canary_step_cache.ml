open Base

(* Step result cache: maps cache_key → entry.
   cache_key = "cache_project:tag", e.g. "sqlite:fetch_lib" or "llvm-19:probe_binding_pkg".
   Populated by `cache-sync` reading GH CI results; read by runner to skip known-good steps. *)

type entry = {
  status : string;   (* "success" or "failure" *)
  run_id : int;      (* GH Actions run database ID; 0 = local *)
  at : string;       (* date recorded, e.g. "2026-04-22" *)
}

type t = (string, entry) Hashtbl.t

let make () : t = Hashtbl.create (module String)

let entry_of_json fields =
  let get_s name =
    match List.Assoc.find fields ~equal:String.equal name with
    | Some (`String s) -> s
    | _ -> ""
  in
  let get_i name =
    match List.Assoc.find fields ~equal:String.equal name with
    | Some (`Int i) -> i
    | _ -> 0
  in
  { status = get_s "status"; run_id = get_i "run_id"; at = get_s "at" }

let of_json (json : Yojson.Basic.t) : t =
  let tbl = make () in
  (match json with
   | `Assoc pairs ->
     List.iter pairs ~f:(fun (key, v) ->
         match v with
         | `Assoc fields -> Hashtbl.set tbl ~key ~data:(entry_of_json fields)
         | _ -> ())
   | _ -> ());
  tbl

let to_json (tbl : t) : Yojson.Basic.t =
  let pairs =
    Hashtbl.to_alist tbl
    |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)
    |> List.map ~f:(fun (key, e) ->
           ( key,
             `Assoc
               [ ("status", `String e.status);
                 ("run_id", `Int e.run_id);
                 ("at", `String e.at) ] ))
  in
  `Assoc pairs

let load ~path : t =
  if Stdlib.Sys.file_exists path then
    (try Yojson.Basic.from_file path |> of_json
     with _ -> make ())
  else make ()

let save ~path (tbl : t) =
  let oc = Stdlib.open_out path in
  Yojson.Basic.pretty_to_channel oc (to_json tbl);
  Stdlib.output_char oc '\n';
  Stdlib.close_out oc

let lookup (tbl : t) ~key = Hashtbl.find tbl key
let record (tbl : t) ~key entry = Hashtbl.set tbl ~key ~data:entry
let is_success tbl ~key =
  match Hashtbl.find tbl key with
  | Some { status = "success"; _ } -> true
  | _ -> false

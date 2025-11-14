open Base
open Compilers

module Objinfo = struct
  type extra = {
    c_object_files : link_spec list; (* From "Extra C object files:" *)
    c_options : link_opt list; (* From "Extra C options:" *)
    dlloader_libs : link_spec list;
        (* From "Extra dynamically-loaded libraries:" *)
  }

  (* 
ocamlobjinfo z3ml.cma | grep -E 'Extra'
Extra C object files: -lz3ml -L/home/ex/.opam/5.3.0/lib/stublibs -L/home/ex/.opam/5.3.0/.opam-switch/build/z3.dev/build -lz3 -lstdc++ -lpthread
Extra C options: -Wl,-rpath,/home/ex/.opam/5.3.0/.opam-switch/build/z3.dev/build:$ORIGIN/../libz3.so:/home/ex/.opam/5.3.0/lib/stublibs:@rpath/dllz3ml.so
Extra dynamically-loaded libraries: -lz3ml

ocamlobjinfo z3ml.cmxa | grep -E 'Extra'
Extra C object files: -lz3ml -L/home/ex/.opam/5.3.0/lib/stublibs -L/home/ex/.opam/5.3.0/.opam-switch/build/z3.dev/build -lz3 -lstdc++ -lpthread
Extra C options: -Wl,-rpath,/home/ex/.opam/5.3.0/.opam-switch/build/z3.dev/build:$ORIGIN/../libz3.so:/home/ex/.opam/5.3.0/lib/stublibs:@rpath/dllz3ml.so
*)

  let inspect_cmd : _ format4 = "ocamlobjinfo %s | grep -E 'Extra'"

  let parse_libspec_token (tok : string) : link_spec =
    if String.is_prefix tok ~prefix:"-l" && String.length tok > 2 then
      L_lib (String.drop_prefix tok 2)
    else if String.is_prefix tok ~prefix:"-L" && String.length tok > 2 then
      L_Lpath (String.drop_prefix tok 2)
    else L_other tok

  (* For "Extra C object files:" and "Extra dynamically-loaded libraries:" *)
  let parse_libspec_list (payload : string) : link_spec list =
    split_words payload |> List.map ~f:parse_libspec_token
  (* For "Extra C options:" 
   recognize -Wl,-rpath,<p1:p2:...>，and convert <...> to string list。 *)

  let pp_extras ?(sep = Fmt.any ": ") fmt extra =
    Fmt.pf fmt "Extra C object files: [%a]@."
      Fmt.(list ~sep pp_link_spec)
      extra.c_object_files;
    Fmt.pf fmt "Extra C options: [%a]@."
      Fmt.(list ~sep pp_link_opt)
      extra.c_options;
    Fmt.pf fmt "Extra dynamically-loaded libraries: [%a]@."
      Fmt.(list ~sep pp_link_spec)
      extra.dlloader_libs

  let parse_extras (s : string) : extra =
    let c_object_files = ref [] in
    let c_options = ref [] in
    let dlloader_libs = ref [] in

    let handle_line (line : string) =
      let line = String.strip line in
      match String.lsplit2 ~on:':' line with
      | None -> ()
      | Some (hdr, rest) ->
          let payload = String.strip rest in
          if String.is_prefix hdr ~prefix:"Extra C object files" then
            c_object_files := parse_libspec_list payload
          else if String.is_prefix hdr ~prefix:"Extra C options" then
            c_options := parse_c_options payload
          else if
            String.is_prefix hdr ~prefix:"Extra dynamically-loaded libraries"
          then dlloader_libs := parse_libspec_list payload
          else ()
    in

    String.split_lines s |> List.iter ~f:handle_line;
    {
      c_object_files = !c_object_files;
      c_options = !c_options;
      dlloader_libs = !dlloader_libs;
    }
end

(* cma file *)
type file_cma = { path : string; extra : Objinfo.extra }

let file_cma_of_objinfo path s : file_cma =
  { path; extra = Objinfo.parse_extras s }

let dump_file_cma fcmo =
  Fmt.pr "File: %s@." fcmo.path;
  Fmt.pr "%a" (Objinfo.pp_extras ~sep:(Fmt.any "; ")) fcmo.extra

(* cmxa file *)
type file_cmxa = { path : string; extra : Objinfo.extra }

let file_cmxa_of_objinfo path s : file_cmxa =
  { path; extra = Objinfo.parse_extras s }

(* META file *)
let parse_fl_meta path = In_channel.open_text path |> Fl_metascanner.parse

(* let dump_file_fl_meta fmeta =
  Fmt.pr "File: %s@." fmeta.path;
  Fl_metascanner.print Out_channel.stdout fmeta.findlib_meta *)

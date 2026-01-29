open Base
open Tola_std
open Ocamls

(* 
For the binding and resolving perspective, a value in the language is either
a key, an artifact, or a map.
For a key, it should support key namespace operations.
For an artifact, it should check for existence, and external tools to change the artifact.
For a map, it should support map operations.

File, file path and key are key, file content is the arficat.

Since resolving is a compositional steps, 
*)

(* See https://github.com/ocaml/opam/blob/master/src/state/opamSysPoll.ml 
For ELF parser: see
https://opam.ocaml.org/packages/bap-elf/
https://github.com/let-def/owee
https://github.com/ashay/owl

For more glob files
https://ocaml.org/p/path_glob/0.3/doc/index.html#path_glob:-checking-glob-patterns-on-paths.
*)

(* 
build tools: dune, cmake, ocamlc, makefile (dryrun),...
pkgm: 
path : environment variable, system path, @rpath, ...
flags: 
...
check_utop_usability 
*)

type file_content =
  (* system *)
  | (* .o *) Object_file
  | Shared_library of {
      os : OpamStd.Sys.os;
      object_deps : Shared_library.binary_deps;
    }
  | Static_library of { os : OpamStd.Sys.os }
  | Executable of { os : OpamStd.Sys.os }
  (* OCaml source *)
  | (* .ml *) Ocaml_source
  | (* .mli *) Ocaml_interface_source
  (* OCaml compiled & bytecode *)
  | (* .cmi *) Ocaml_compiled_interface
  | (* .cmo *) Ocaml_bytecode_object
  | (* .cma *) Ocaml_bytecode_library of { extra : Objinfo.extra }
  (* OCaml native *)
  | (* .cmx *) Ocaml_native_object
  | (* .cmxs *)
    Ocaml_native_shared_object of { object_deps : Shared_library.binary_deps }
  | (* .cmxa *) Ocaml_native_library of { extra : Objinfo.extra }
  (* opam *)
  | Findlib_meta of { findlib_meta : Fl_metascanner.pkg_expr }
  (* others *)
  | Unknown

type file_info = {
  (* shared *)
  path : string;
  ext : string option;
  (* special *)
  content : file_content;
}

let name_of_content kind =
  match kind with
  (* system *)
  | Object_file -> "object file"
  | Shared_library _ -> "shared library"
  | Static_library _ -> "static library"
  | Executable _ -> "executable"
  (* OCaml source *)
  | Ocaml_source -> "ocaml source file"
  | Ocaml_interface_source -> "ocaml interface source file"
  (* OCaml compiled & bytecode *)
  | Ocaml_compiled_interface -> "ocaml compiled interface"
  | Ocaml_bytecode_object -> "ocaml bytecode object"
  | Ocaml_bytecode_library _ -> "ocaml bytecode library"
  (* OCaml native *)
  | Ocaml_native_object -> "ocaml native object"
  | Ocaml_native_shared_object _ -> "ocaml native shared object"
  | Ocaml_native_library _ -> "ocaml native library"
  | Findlib_meta _ -> "findlib META file"
  (* others *)
  | Unknown -> "unknown"

let pp_file_info fmt fi =
  Fmt.pf fmt "File path: %s@." fi.path;
  (match fi.ext with
  | Some ext -> Fmt.pf fmt "Extension: %s@." ext
  | None -> Fmt.pf fmt "Extension: (none)@.");
  Fmt.pf fmt "Content type: %s@." (name_of_content fi.content)

let pp_file_info_short fmt fi =
  (match fi.ext with
  | Some ext -> Fmt.pf fmt "[%s]" ext
  | None -> Fmt.pf fmt "[_]");
  Fmt.pf fmt "%s" (name_of_content fi.content)

let simple_glob pat s =
  let re = Re.Glob.glob pat |> Re.compile in
  Re.execp re s

let inspect_file_with_ext inspect_config abs_path _file ext =
  let open Config in
  let run0 cmd0 =
    let cmd = Fmt.str cmd0 abs_path in
    (* Fmt.pr "[Tool] %s@." cmd; *)
    Tola_cmd.run_s cmd
  in
  let parse_macho () =
    Shared_library.Macho
      {
        otool_deps =
          run0 Shared_library.otool_inspect_cmd
          |> Shared_library.parse_otool_L_output;
      }
  in
  let parse_elf () =
    Shared_library.Elf
      {
        declared_dep =
          run0 Shared_library.elf_inspect_cmd |> Shared_library.parse_readelf;
      }
  in
  let content =
    match ext with
    | "so" ->
        Shared_library
          {
            os = Std.the_os;
            object_deps =
              (* TODO: should be a matching instead of bool *)
              (if inspect_config.so_as_dylib then parse_macho ()
               else parse_elf ());
          }
    | "dylib" ->
        Shared_library { os = Std.the_os; object_deps = parse_macho () }
    | "a" -> run0 "ar t %s" |> Fn.const Unknown
    | "lib" -> run0 "ar t %s " |> Fn.const Unknown
    | "cma" ->
        Ocaml_native_library
          { extra = Objinfo.parse_extras (run0 Objinfo.inspect_cmd) }
    | "cmxs" ->
        Ocaml_native_shared_object
          {
            object_deps =
              (if Std.is_macos then parse_macho () else parse_elf ());
          }
    | "cmxa" ->
        Ocaml_native_library
          { extra = Objinfo.parse_extras (run0 Objinfo.inspect_cmd) }
    | "owner" | _ -> run0 "file %s" |> Fn.const Unknown
    (* | "exe" -> [ "file %s" ] *)
    (* | "o" -> [ "nm %s" ] *)
    (* | "ml" | "mli" ->  *)
    (* | "cmi" -> 
  | "cmo" ->  *)
    (* | "cmx" -> [] *)
  in

  { path = abs_path; ext = Some ext; content }

let inspect_file_no_ext path base_name =
  match base_name with
  | "META" ->
      let findlib_meta = Ocamls.parse_fl_meta path in
      { path; ext = None; content = Findlib_meta { findlib_meta } }
      (* |> Ocamls.dump_file_fl_meta *)
  | _ -> { path; ext = None; content = Unknown }

let inspect_file ?(inspect_config = Config.default_inspect_config) abs_path :
    file_info =
  let base_name = Filename_base.basename abs_path in
  let _base, ext0 = Filename_base.split_extension base_name in
  match (Sys_unix.is_file abs_path, ext0) with
  | `Yes, Some ext ->
      inspect_file_with_ext inspect_config abs_path base_name ext
  | `Yes, None -> inspect_file_no_ext abs_path base_name
  | _ -> { path = abs_path; ext = None; content = Unknown }

let inspect_dir ?pat dir0 =
  let dir = expand_home_dir dir0 in
  Sys_unix.ls_dir dir
  |> List.filter_map ~f:(fun file ->
      let matched =
        match pat with Some pat -> simple_glob pat file | None -> true
      in
      if matched then Some (inspect_file (dir $/ file)) else None)

let check_no_internal_path internal_paths = function
  | Ocaml_bytecode_library bclib ->
      Ocamls.check_extra internal_paths bclib.extra
  | Ocaml_native_library nlib -> Ocamls.check_extra internal_paths nlib.extra
  | _ -> Result.Ok ()

let () =
  (* ignore @@ inspect_dir "~/.opam/5.3.0/lib/z3";
  ignore @@ inspect_dir ~pat:"*z3*" "~/.opam/5.3.0/lib/stublibs"; *)
  ()
(* run_tool "~/.opam/5.3.0/lib/z3" "~/.opam/5.3.0/lib/stublibs/dllz3ml.so";
  run_tool "~/.opam/5.3.0/lib/z3" "~/.opam/5.3.0/lib/z3/z3.o"; *)

(* TODO:
should handle multiple-dots e.g.
../stublibs/dllz3ml.so*       ../stublibs/libz3.so.4.15*           ../stublibs/libz3.so.4.15.owner
../stublibs/dllz3ml.so.owner  ../stublibs/libz3.so.4.15.4.0*       ../stublibs/libz3.so.owner
../stublibs/libz3.so*         ../stublibs/libz3.so.4.15.4.0.owner
*)

(* 
  let un = OpamStd.Sys.uname () in
  Fmt.pr "machine: %s; release: %s; sysname: %s@.\n" un.machine un.release
    un.sysname; 
  detect_os () ; *)
(* machine: x86_64; release: 5.15.167.4-microsoft-standard-WSL2; sysname: Linux 
  Detected OS: Linux
  *)

(* 
(* not used *)
let ext_of_content kind =
  match kind with
  (* system *)
  | Object_file -> "o"
  | Shared_library { os } -> Shared_library.shared_ext os
  | Static_library { os } -> Shared_library.static_ext os
  | Executable { os } -> Shared_library.exe_ext os
  (* OCaml source *)
  | Ocaml_source -> "ml"
  | Ocaml_interface_source -> "mli"
  (* OCaml compiled & bytecode *)
  | Ocaml_compiled_interface -> "cmi"
  | Ocaml_bytecode_object -> "cmo"
  | Ocaml_bytecode_library -> "cma"
  (* OCaml native *)
  | Ocaml_native_object -> "cmx"
  | Ocaml_native_shared_object -> "cmxs"
  | Ocaml_native_library -> "cmxa"
  (* others *)
  | Unknown -> ""
  
let tools_of_content kind =
  match kind with
  | Shared_library { os } -> [ Shared_library.tool_dep os ]
  | Executable _ -> [ "file" ]
  | Static_library _ -> [ "ar t"; "objdump -t" ]
  | Object_file -> [ "nm" ]
  | Ocaml_compiled_interface -> [ "ocamlobjinfo" ]
  | Ocaml_bytecode_object -> [ "ocamlobjinfo" ]
  | Ocaml_bytecode_library -> [ "ocamlobjinfo" ]
  | Ocaml_native_object -> [ "ocamlobjinfo" ]
  | Ocaml_native_shared_object -> [ "ocamlobjinfo"; "objdump -t" ]
  | Ocaml_native_library -> [ "ocamlobjinfo" ]
  | _ -> [ "file" ]

let content_of_ext ext =
  (* system *)
  match ext with
  | "o" -> Object_file
  | "so" -> Shared_library { os = Linux }
  | "dylib" -> Shared_library { os = Darwin }
  | "dll" -> Shared_library { os = Win32 }
  | "lib" -> Static_library { os = Win32 }
  | "a" -> Static_library { os = Linux }
  | "exe" -> Executable { os = Win32 }
  (* ocaml src and interface *)
  | "ml" -> Ocaml_source
  | "mli" -> Ocaml_interface_source
  | "cmi" -> Ocaml_compiled_interface
  | "cmo" -> Ocaml_bytecode_object
  | "cma" -> Ocaml_bytecode_library
  | "cmx" -> Ocaml_native_object
  | "cmxs" -> Ocaml_native_shared_object
  | "cmxa" -> Ocaml_native_library
  | _ -> Unknown 

(* let entity_name = entity_name_of_ext ext in
  Fmt.pr "[File] %s@.[Ext][%s] %s@." file ext entity_name; *)

let entity_name_of_ext ext = ext |> content_of_ext |> name_of_content  
  *)

(* 
legacy ext-based dispatch

let entity_name_of_ext ext =
  match ext with
  (* native (binary) *)
  | "o" -> "object file"
  | "so" -> "shared library (linux)"
  | "dylib" -> "shared library (macos)"
  | "dll" -> "shared library (windows)"
  | "lib" -> "static library"
  | "a" -> "static library"
  | "exe" -> "executable"
  (* ocaml src and interface *)
  | "ml" -> "ocaml source file"
  | "mli" -> "ocaml interface source file"
  | "cmi" -> "ocaml interface"
  (* ocaml bytecode *)
  | "cmo" -> "ocaml bytecode object"
  | "cma" -> "ocaml bytecode library"
  (* ocaml native *)
  | "cmx" -> "ocaml native object"
  | "cmxs" -> "ocaml native shared object"
  | "cmxa" -> "ocaml native library"
  | _ -> "binary"

let tools_of_ext ext =
  match ext with
  | "so" | "dylib" | "dll" -> [ Shared_library.tool_dep Std.the_os ]
  | "exe" -> [ "file" ]
  (* | "o" -> "nm" *)
  | "a" -> [ "ar t"; "objdump -t" ]
  | "lib" -> [ "ar t" ]
  (* | "ml" | "mli" -> "ocamlc -c" *)
  | "cmi" -> [ "ocamlobjinfo" ]
  | "cmo" -> [ "ocamlobjinfo" ]
  | "cma" -> [ "ocamlobjinfo" ]
  | "cmx" -> [ "ocamlobjinfo" ]
  | "cmxs" -> [ "ocamlobjinfo"; "objdump -t" ]
  | "cmxa" -> [ "ocamlobjinfo" ]
  | _ -> [ "file" ]
*)

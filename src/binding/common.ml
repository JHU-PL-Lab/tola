open Base
open Tola_std

(* See https://github.com/ocaml/opam/blob/master/src/state/opamSysPoll.ml 
For ELF parser: see
https://opam.ocaml.org/packages/bap-elf/
https://github.com/let-def/owee
https://github.com/ashay/owl

For more glob files
https://ocaml.org/p/path_glob/0.3/doc/index.html#path_glob:-checking-glob-patterns-on-paths.
*)

open OpamStd.Sys

let ext os =
  match os with
  | Linux -> "so"
  | Darwin -> "dylib"
  | Win32 -> "dll"
  | _ -> raise (Failure "Unsupported OS for shared library")

let tool_symbol os =
  match os with
  | Linux -> "nm -D"
  | Darwin -> "nm -gU"
  | _ -> failwith "Unsupported OS for symbol tool"

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

let cmd_and_handler_pairs_of_ext ext : (_ format4 * _) list =
  let _dump result = Fmt.pr "[Result]%s@." result in
  let dump _ = () in
  let elf_pair =
    ( ("readelf -d %s | grep -E 'RPATH|RUNPATH|SONAME|NEEDED'" : _ format4),
      Shared_library.dump_readelf )
  in
  let ldd_pair = (("ldd %s " : _ format4), Shared_library.dump_ldd) in
  let otool_pair = (("otool -L %s" : _ format4), Shared_library.dump_otool_L) in
  let ocamlc_library_pair =
    (("ocamlobjinfo %s | grep -E 'Extra'" : _ format4), Ocamls.dump_extras)
  in
  match ext with
  | "so" -> [ elf_pair; ldd_pair ]
  | "dylib" -> [ otool_pair ]
  | "a" -> ("ar t %s", dump) :: []
  | "lib" -> ("ar t %s ", dump) :: []
  | "cma" -> [ ocamlc_library_pair ]
  | "cmxs" -> [ elf_pair; ldd_pair ]
  | "cmxa" -> [ ocamlc_library_pair ]
  | "owner" | _ -> ("file %s", dump) :: []
(* | "exe" -> [ "file %s" ] *)
(* | "o" -> [ "nm %s" ] *)
(* | "ml" | "mli" ->  *)
(* | "cmi" -> 
  | "cmo" ->  *)
(* | "cmx" -> [] *)

(* TODO:
should handle multiple-dots e.g.
../stublibs/dllz3ml.so*       ../stublibs/libz3.so.4.15*           ../stublibs/libz3.so.4.15.owner
../stublibs/dllz3ml.so.owner  ../stublibs/libz3.so.4.15.4.0*       ../stublibs/libz3.so.owner
../stublibs/libz3.so*         ../stublibs/libz3.so.4.15.4.0.owner
*)

(* 
ocamlobjinfo z3ml.cma | grep -E 'Extra'
Extra C object files: -lz3ml -L/home/ex/.opam/5.3.0/lib/stublibs -L/home/ex/.opam/5.3.0/.opam-switch/build/z3.dev/build -lz3 -lstdc++ -lpthread
Extra C options: -Wl,-rpath,/home/ex/.opam/5.3.0/.opam-switch/build/z3.dev/build:$ORIGIN/../libz3.so:/home/ex/.opam/5.3.0/lib/stublibs:@rpath/dllz3ml.so
Extra dynamically-loaded libraries: -lz3ml

ocamlobjinfo z3ml.cmxa | grep -E 'Extra'
Extra C object files: -lz3ml -L/home/ex/.opam/5.3.0/lib/stublibs -L/home/ex/.opam/5.3.0/.opam-switch/build/z3.dev/build -lz3 -lstdc++ -lpthread
Extra C options: -Wl,-rpath,/home/ex/.opam/5.3.0/.opam-switch/build/z3.dev/build:$ORIGIN/../libz3.so:/home/ex/.opam/5.3.0/lib/stublibs:@rpath/dllz3ml.so
*)

let simple_glob pat s =
  let re = Re.Glob.glob pat |> Re.compile in
  Re.execp re s

let inspect_dir ?pat dir0 =
  let dir = expand_home_dir dir0 in
  let handle_file fullpath file ext =
    let entity_name = entity_name_of_ext ext in
    Fmt.pr "[File] %s@.[Ext][%s] %s@." file ext entity_name;
    List.iter (cmd_and_handler_pairs_of_ext ext) ~f:(fun (cmd0, handle) ->
        let cmd = Fmt.str cmd0 fullpath in
        Fmt.pr "[Tool] %s@." cmd;
        Cmd.run_s cmd |> handle)
  in
  let handle_file_no_ext fullpath file =
    Fmt.pr "[File] %s@.[No Ext] %s@." fullpath file;
    match file with
    | "META" ->
        In_channel.open_text fullpath
        |> Fl_metascanner.parse
        |> Fl_metascanner.print Out_channel.stdout
    | _ -> ()
  in
  Sys_unix.ls_dir dir
  |> List.iter ~f:(fun file ->
         let matched =
           match pat with Some pat -> simple_glob pat file | None -> true
         in
         if matched then (
           let fullpath = dir $/ file in
           (* Fmt.pr "[Dir] %s + %s = %s@." dir file filepath; *)
           let _base, ext0 = Filename_base.split_extension file in
           (match ext0 with
           | Some ext -> handle_file fullpath file ext
           | None -> handle_file_no_ext fullpath file);
           Fmt.pr "@."))

let () =
  inspect_dir "~/.opam/5.3.0/lib/z3";
  inspect_dir ~pat:"*z3*" "~/.opam/5.3.0/lib/stublibs";
  ()
(* run_tool "~/.opam/5.3.0/lib/z3" "~/.opam/5.3.0/lib/stublibs/dllz3ml.so";
  run_tool "~/.opam/5.3.0/lib/z3" "~/.opam/5.3.0/lib/z3/z3.o"; *)

(* 
  let un = OpamStd.Sys.uname () in
  Fmt.pr "machine: %s; release: %s; sysname: %s@.\n" un.machine un.release
    un.sysname; 
  detect_os () ; *)
(* machine: x86_64; release: 5.15.167.4-microsoft-standard-WSL2; sysname: Linux 
  Detected OS: Linux
  *)

(* 

  # artifact files
  ...

  # pkgms
  opam 
  debian/homebrew : record-with-get-and-set
  
  path-related : env...
  *)

(* 
  '~'
  '*'
  *)

(** Direct-compile primitives — gcc, ocamlfind ocamlopt, ar,
    symlink.

    For artifacts canary {i owns} (tiny today; potential
    future first-party fixtures), we invoke compilers directly
    rather than route through cmake/dune/make. The
    "owner decides the build" principle:
    [doc/canary/design/tiny.md] §7.7. This dissolves the
    dune-in-dune lock issue definitively (no dune subprocess
    exists), matches "less external build systems" while
    keeping "external tools ok" (compilers are tools), and
    keeps flags visible + auditable.

    For real upstream projects (z3, llvm, sqlite), canary
    continues to shell out to their own build systems via
    [Canary_build_cmd]'s cmake/ninja/dune wrappers — we're a
    guest there, not the owner.

    All primitives return shell command strings. Callers
    execute them (via [Sys.command] or similar).
    Composable with [Canary_build_cmd.with_marker]. *)

open Base

let join = String.concat ~sep:" "

let squeeze s =
  let rec loop s =
    let s' = String.substr_replace_all s ~pattern:"  " ~with_:" " in
    if String.equal s s' then s else loop s'
  in
  loop s

(** [cc_compile_obj ~include_dirs ~src ~out ()] — compile a C
    source to a PIC object file.
    Emits: [gcc -c -fPIC -I<dir1> [-I<dir2>...] <src> -o <out>] *)
let cc_compile_obj ?(cc = "gcc") ?(include_dirs = []) ?(defines = []) ~src ~out ()
    : string =
  let includes = List.map include_dirs ~f:(fun d -> "-I" ^ d) |> join in
  let defs = List.map defines ~f:(fun d -> "-D" ^ d) |> join in
  squeeze (Printf.sprintf "%s -c -fPIC %s %s %s -o %s" cc defs includes src out)

(** [cc_link_shared] — link .o files (and/or a bare .c) into a
    shared library.

    Optional flags:
    - [soname]: emit [-Wl,-soname,<so>]
    - [version_script]: emit [-Wl,--version-script=<path>]
    - [rpath]: emit [-Wl,-rpath,<dir>]
    - [include_dirs]: [-I<dir>] entries (only needed when
      [inputs] contains .c sources compiled inline)
    - [library_dirs]: [-L<dir>] entries
    - [libs]: [-l<name>] entries *)
let cc_link_shared
    ?(cc = "gcc")
    ?soname
    ?version_script
    ?rpath
    ?(include_dirs = [])
    ?(library_dirs = [])
    ?(libs = [])
    ~inputs ~out () : string =
  let opt_flag = function Some s -> s | None -> "" in
  let parts = [
    cc; "-shared"; "-fPIC";
    List.map include_dirs ~f:(fun d -> "-I" ^ d) |> join;
    List.map library_dirs ~f:(fun d -> "-L" ^ d) |> join;
    opt_flag (Option.map soname ~f:(Printf.sprintf "-Wl,-soname,%s"));
    opt_flag (Option.map version_script ~f:(Printf.sprintf "-Wl,--version-script=%s"));
    opt_flag (Option.map rpath ~f:(Printf.sprintf "-Wl,-rpath,%s"));
    join inputs;
    List.map libs ~f:(fun l -> "-l" ^ l) |> join;
    "-o"; out;
  ] in
  squeeze (join parts)

(** [ocaml_compile_unit ~build_dir ~src ~target ()] — compile one
    .mli or .ml to .cmi or .cmx.
    Emits:
    [ocamlfind ocamlopt -bin-annot -I <build_dir> -c <src> -o <target>] *)
let ocaml_compile_unit ?(ocamlfind = "ocamlfind") ~build_dir ~src ~target () : string =
  Printf.sprintf "%s ocamlopt -bin-annot -I %s -c %s -o %s"
    ocamlfind build_dir src target

(** [ocaml_archive_cmxa ~inputs ~out ()] — pack .cmx units + cclib
    flags into a .cmxa.
    [cclib_libs] is a list of library names (bare, without [-l]);
    they render as pairs of [-cclib -l<name>]. *)
let ocaml_archive_cmxa
    ?(ocamlfind = "ocamlfind")
    ?(cclib_libs = [])
    ~inputs ~out () : string =
  let cclibs =
    List.concat_map cclib_libs ~f:(fun lib -> ["-cclib"; "-l" ^ lib])
    |> join in
  squeeze
    (Printf.sprintf "%s ocamlopt -a %s %s -o %s"
       ocamlfind (join inputs) cclibs out)

(** [ar_archive ~inputs ~out ()] — bundle .o files into a
    static archive .a. Emits: [ar rcs <out> <inputs>] *)
let ar_archive ?(ar = "ar") ~inputs ~out () : string =
  Printf.sprintf "%s rcs %s %s" ar out (join inputs)

(** [symlink ~target ~linkname ()] — force-create a symbolic
    link. Emits: [ln -sf <target> <linkname>] *)
let symlink ~target ~linkname () : string =
  Printf.sprintf "ln -sf %s %s" target linkname

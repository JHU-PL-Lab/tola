module type PACKAGE = sig
  type pid
  type pkg

  val pid_to_str : pid -> string
  val str_to_pid : string -> pid
  val pkg_to_str : pkg -> string
  val str_to_pkg : string -> pkg
  (* val pp_pid : pid Fmt.t *)
  (* val pp_pkg : pkg Fmt.t *)
end

(* : PACKAGE with type pid = string and type pkg = string *)
module String_pkg = struct
  type pid = string
  type pkg = string

  let pid_to_str s = s
  let str_to_pid s = s
  let pkg_to_str s = s
  let str_to_pkg s = s
  (* let pp_pid = Fmt.string *)
  (* let pp_pkg = Fmt.string *)
end

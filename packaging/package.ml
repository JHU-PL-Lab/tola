module type PACKAGE = sig
  type pid
  type pkg

  val pp_pid : pid Fmt.t
  val pp_pkg : pkg Fmt.t
end

(* : PACKAGE with type pid = string and type pkg = string *)
module String_pkg = struct
  type pid = string
  type pkg = string

  let pp_pid = Fmt.string
  let pp_pkg = Fmt.string
end

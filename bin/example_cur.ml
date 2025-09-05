(* dune: (executable (name main)
           (libraries current current_web fpath fmt logs logs.lwt lwt)) *)

(* open Current.Syntax *)

(* module Project = struct
  type t = Fpath.t

  let v p = Current.return p
end

module Library = struct
  type t = Fpath.t

  let v p = Current.return p
end

let copy_step ~src ~dst =
  Current.Process.exec ~label:"cp project→library" ~cancellable:true
    ~cmd:[ "cp"; "-rT"; Fpath.to_string src; Fpath.to_string dst ]
    ()

let pipeline () =
  let* _proj = Project.v (Fpath.v "project") in
  (* 节点 1 *)
  let lib_dir = Fpath.v "library" in
  let* () = copy_step ~src:(Fpath.v "project") ~dst:lib_dir in
  (* 节点 2 *)
  Library.v lib_dir (* 节点 3 *)

let () =
  Logging.init ~level:Logs.Info ();
  let cfg = Current.Config.v ~app_id:"demo" () in
  let engine = Current.Engine.create ~config:cfg (pipeline ()) in
  Current_web.run ~engine ~has_role:Current_web.Site.dev ~mode:`Dev () *)

let eval e =
  try
    let _ = e in
    Stdio.eprintf "Evaluated: %d@." e;
    raise (Failure "This is a demo failure to show error handling")
  with exn ->
    Printexc.print_backtrace stderr;
    Stdio.eprintf "Catched. @.";
    Out_channel.flush stderr;
    (* Unix.sleepf 0.1; *)
    raise exn

let () = eval 42

type host_lang = Host_native | Host_guest
type guest_lang = Guest

let embed = function Guest -> Host_guest

(* reflection *)
let project_guest = function
  | Host_native -> failwith "native"
  | Host_guest -> Guest

let _ = Host_native

(*
   host native reflection
   guest specific reflection
*)

(*
   host interp
   guest interp (if deep embedding)
*)

(*
   external analyse
   internal analyse
*)

(*
   en-host
   de-host
*)

(* I think now the problem is neither shallow nor deep
   but a host invasion

   Maybe it's a staged computation. need check
*)

let () = ()

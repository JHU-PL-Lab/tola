(* Probe: ctypes-foreign dynamic FFI — canary's first Dynamic_ffi project.
   ctypes-foreign resolves C functions at runtime via libffi (no
   compile-time C stub). Calls libc's abs() through a dynamically-built
   function type and round-trips a value. *)
open Ctypes
open Foreign

let () =
  let abs_ = foreign "abs" (int @-> returning int) in
  let r = abs_ (-42) in
  Printf.printf "abs(-42) = %d\n" r;
  if r = 42 then print_endline "ctypes-foreign ok"
  else (Printf.printf "MISMATCH: got %d\n" r; exit 1)

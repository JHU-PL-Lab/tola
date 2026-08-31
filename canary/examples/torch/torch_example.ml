(* Probe: the opam `torch` binding over libtorch. Builds a tensor, runs a
   real reduction through the C++ shim, and checks the arithmetic — a
   genuine call into libtorch_cpu.so, not a link check.

   IT PRINTS THE RESOLVED LIBRARY AND THE LIBRARY'S OWN VERSION, because
   torch's lib axis has two provisions that the OCaml surface cannot tell
   apart (opam's libtorch 2.1.2 and the upstream 2.2.1 zip export the same
   OCaml API). Two identity lines, for the two things that can be wrong:

   - `torch resolved: <path>` — from /proc/self/maps, the file the loader
     actually mapped (the zlib convention). This is what the vendored
     world asserts on: LD_LIBRARY_PATH is a preference, and a silent
     fallback to the opam copy would otherwise pass for the wrong reason.
   - `torch build-version: <v>` — libtorch ships a `build-version` file
     beside its libdir, so unlike zlib this library CAN name its own
     version. Printed next to the path so a reader sees both the artifact
     and its claim. *)

let resolved_libtorch () =
  match Sys.file_exists "/proc/self/maps" with
  | false -> "unknown (no /proc/self/maps)"
  | true ->
      let ic = open_in "/proc/self/maps" in
      let unset = "not mapped" in
      let found = ref unset in
      (try
         while true do
           let line = input_line ic in
           (* the last field of a maps line is the backing path *)
           match String.rindex_opt line ' ' with
           | None -> ()
           | Some i ->
               let path =
                 String.sub line (i + 1) (String.length line - i - 1)
               in
               let base = Filename.basename path in
               (* libtorch_cpu.so carries the implementation; libtorch.so
                  is a 7KB stub that just pulls it in, so name the one
                  that actually answers *)
               if String.equal base "libtorch_cpu.so" && String.equal !found unset
               then found := path
         done
       with End_of_file -> ());
      close_in ic;
      !found

(* `build-version` sits one level above the libdir: <root>/lib/libtorch_cpu.so
   → <root>/build-version. Derived from the resolved path so it reports the
   version of the library that ANSWERED, not of some declared directory. *)
let build_version_of path =
  match String.equal path "not mapped" with
  | true -> "unknown"
  | false -> (
      let f = Filename.concat (Filename.dirname (Filename.dirname path)) "build-version" in
      match Sys.file_exists f with
      | false -> "unknown (no build-version file)"
      | true ->
          let ic = open_in f in
          let v = try input_line ic with End_of_file -> "empty" in
          close_in ic; v)

let () =
  (* a real reduction: sum [1..8] = 36, computed by libtorch *)
  let xs = Array.init 8 (fun i -> float_of_int (i + 1)) in
  let t = Torch.Tensor.of_float1 xs in
  let total = Torch.Tensor.sum t |> Torch.Tensor.to_float0_exn in
  let expected = Array.fold_left ( +. ) 0. xs in
  let path = resolved_libtorch () in
  Printf.printf "torch resolved: %s\n" path;
  Printf.printf "torch build-version: %s\n" (build_version_of path);
  Printf.printf "torch sum: %g (expected %g)\n" total expected;
  if Float.abs (total -. expected) < 1e-6 then print_endline "torch ok"
  else (print_endline "MISMATCH: reduction differs"; exit 1)

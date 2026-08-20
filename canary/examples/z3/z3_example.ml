open Z3

(* WHICH libz3 ANSWERED (2026-08-20, plan item A2). [Version.to_string] is
   the library's own report, which is evidence; this is the loader's, which
   is enforcement. z3's cross cells put a DIFFERENT libz3 in front of the
   same binding — the dev build tree, the staged install prefix, or apt's
   4.8.12 — and until now nothing failed if the ambient one answered
   instead of the world's. Reading /proc/self/maps names the file that was
   actually mapped, so a canary world assertion can grep for the directory
   this scenario declares.

   Same convention as zlib's and zstd's probes; kept identical on purpose
   so one [Canary_world.Log_names] shape works across projects. *)
let resolved_libz3 () =
  match Sys.file_exists "/proc/self/maps" with
  | false -> "unknown (no /proc/self/maps)"
  | true ->
      let ic = open_in "/proc/self/maps" in
      let found = ref "not mapped (statically linked?)" in
      (try
         while true do
           let line = input_line ic in
           match String.rindex_opt line ' ' with
           | None -> ()
           | Some i ->
               let path =
                 String.sub line (i + 1) (String.length line - i - 1)
               in
               let base = Filename.basename path in
               if
                 String.length base >= 8
                 && String.sub base 0 8 = "libz3.so"
                 && String.equal !found "not mapped (statically linked?)"
               then found := path
         done
       with End_of_file -> ());
      close_in ic;
      !found

let () =
  let ctx = mk_context [] in
  let x = Arithmetic.Integer.mk_const ctx (Symbol.mk_string ctx "x") in
  let solver = Solver.mk_solver ctx None in
  Solver.add solver [ Arithmetic.mk_gt ctx x (Arithmetic.Integer.mk_numeral_i ctx 0) ];
  let status = Solver.check solver [] in
  Printf.printf "z3 version: %s\n" Version.to_string;
  Printf.printf "z3 resolved: %s\n" (resolved_libz3 ());
  Printf.printf "sat status: %s\n" (Solver.string_of_status status)

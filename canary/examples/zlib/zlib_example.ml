(* Probe: camlzip over the system zlib. Round-trips a buffer through
   Zlib.compress / Zlib.uncompress — a real call into libz, not just a
   link check: compress writes a deflate stream and uncompress has to
   reproduce the original bytes exactly.

   It also PRINTS THE RESOLVED LIBRARY. zlib exposes no version through
   camlzip's surface, so a world that repoints LD_LIBRARY_PATH at a
   vendored libz has no version string to assert on. /proc/self/maps
   names the file the loader actually mapped, which is stronger than a
   version anyway — it is the identity of the answering artifact. The
   canary world assert matches on this line, so a silent fallback to the
   system lib fails the world instead of passing for the wrong reason
   (the cairo lesson: two versions can export identical surfaces). *)

let resolved_libz () =
  match Sys.file_exists "/proc/self/maps" with
  | false -> "unknown (no /proc/self/maps)"
  | true ->
      let ic = open_in "/proc/self/maps" in
      let found = ref "not mapped (statically linked?)" in
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
               if
                 String.length base >= 7
                 && String.sub base 0 7 = "libz.so"
                 && String.equal !found "not mapped (statically linked?)"
               then found := path
         done
       with End_of_file -> ());
      close_in ic;
      !found

let () =
  let original = String.concat "" (List.init 200 (fun i ->
      Printf.sprintf "canary zlib probe line %d\n" i)) in
  let n = String.length original in
  (* compress: feed the source through, collect the deflate stream *)
  let buf = Buffer.create (n / 2) in
  let pos = ref 0 in
  Zlib.compress
    (fun bytes ->
      let len = min (Bytes.length bytes) (n - !pos) in
      Bytes.blit_string original !pos bytes 0 len;
      pos := !pos + len;
      len)
    (fun bytes len -> Buffer.add_subbytes buf bytes 0 len);
  let deflated = Buffer.contents buf in
  (* uncompress: feed the deflate stream back, collect the original *)
  let out = Buffer.create n in
  let dpos = ref 0 in
  let dn = String.length deflated in
  Zlib.uncompress
    (fun bytes ->
      let len = min (Bytes.length bytes) (dn - !dpos) in
      Bytes.blit_string deflated !dpos bytes 0 len;
      dpos := !dpos + len;
      len)
    (fun bytes len -> Buffer.add_subbytes out bytes 0 len);
  let round = Buffer.contents out in
  Printf.printf "zlib resolved: %s\n" (resolved_libz ());
  Printf.printf "zlib sizes: original=%d deflated=%d inflated=%d\n" n dn
    (String.length round);
  if String.equal round original then print_endline "camlzip ok"
  else (print_endline "MISMATCH: round-trip differs"; exit 1)

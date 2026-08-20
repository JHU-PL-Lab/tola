(* Probe: the `zstd` OCaml binding over the system libzstd. Round-trips a
   buffer through Zstd.compress / Zstd.decompress — a real call into the
   library, and one whose result is checked byte-for-byte.

   TWO INDEPENDENT WORLD WITNESSES, which is why zstd is a better
   specimen than zlib:

   - Zstd.version () calls ZSTD_versionNumber() in the LOADED library
     (the binding is ctypes-over-stubs, so this is a C call at runtime,
     not a header constant compiled into the binding). It reports which
     libzstd answered, from the library's own code.
   - /proc/self/maps names the FILE the loader mapped, from the loader's
     bookkeeping.

   They can disagree — a stale copy at the expected path, or a version
   the header and the .so disagree about — and when they agree the world
   is pinned twice over. zlib's probe has only the second (camlzip
   exposes no zlibVersion()), so zstd is where the two-witness form gets
   exercised. *)

let resolved_libzstd () =
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
                 String.length base >= 11
                 && String.sub base 0 11 = "libzstd.so."
                 && String.equal !found "not mapped (statically linked?)"
               then found := path
         done
       with End_of_file -> ());
      close_in ic;
      !found

let () =
  let original =
    String.concat ""
      (List.init 200 (fun i ->
           Printf.sprintf "canary zstd probe line %d\n" i))
  in
  let n = String.length original in
  let compressed = Zstd.compress ~level:3 original in
  let round = Zstd.decompress n compressed in
  let maj, min, patch = Zstd.version () in
  Printf.printf "zstd version: %d.%d.%d\n" maj min patch;
  Printf.printf "zstd resolved: %s\n" (resolved_libzstd ());
  Printf.printf "zstd sizes: original=%d compressed=%d restored=%d\n" n
    (String.length compressed) (String.length round);
  if String.equal round original then print_endline "zstd ok"
  else (print_endline "MISMATCH: round-trip differs"; exit 1)

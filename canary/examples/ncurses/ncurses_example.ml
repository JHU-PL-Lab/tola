(* Probe: the `curses` OCaml binding over the system ncursesw.

   WHY IT DOES NOT CALL initscr. `initscr()` is the obvious entry point
   and it is unusable here: it opens the terminal named by $TERM and, when
   that fails, ncurses prints "Error opening terminal" and calls exit(1)
   from inside the library. Canary captures every step's output through a
   pipe (`| tee LOG`), so a probe's stdout is never a tty — initscr would
   abort the probe for a reason that has nothing to do with the library
   under test. `newterm "dumb"` over /dev/null is the headless form: it is
   the same code path (initscr IS newterm plus a stdscr assignment),
   it needs no tty, and it was verified to work with $TERM unset and
   stdout piped before this probe was written.

   THE WORLD IS ASSERTED BY PATH, AND HERE THAT IS THE ONLY OPTION
   (landing.md §3c). apt 6.4 and conda-forge 6.6 export the SAME 463
   symbols under the SAME ten ELF version nodes — measured, diff empty
   both ways — so no symbol-level verdict anywhere can tell the two
   worlds apart. That is cairo's trap, and here it is not a near miss:
   the sets are equal. /proc/self/maps names the FILE the loader mapped,
   which is the identity of the artifact that answered, and the vendored
   world greps for it (`probe_names_lib`).

   The library HAS a version accessor — `curses_version()` returns
   "ncurses 6.4.20240113" under apt — but it lives in libtinfo and the
   `curses` binding does not bind it (no `version` anywhere in
   curses.mli). So zstd's second witness is unavailable through the
   binding even though the C library offers one. Recorded as an upstream
   gap rather than worked around.

   BOTH mapped paths are printed. ncurses ships as two objects and the
   packagers disagree about the second: apt's libncursesw NEEDs
   libtinfo.so.6, conda-forge's NEEDs libtinfow.so.6 (it ships both).
   Printing the pair shows the whole answering closure came from one
   world rather than being spliced across two. *)

let mapped_path ~(prefix : string) : string =
  match Sys.file_exists "/proc/self/maps" with
  | false -> "unknown (no /proc/self/maps)"
  | true ->
      let ic = open_in "/proc/self/maps" in
      let none = "not mapped" in
      let found = ref none in
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
               let n = String.length prefix in
               if
                 String.length base >= n
                 && String.sub base 0 n = prefix
                 && String.equal !found none
               then found := path
         done
       with End_of_file -> ());
      close_in ic;
      !found

let () =
  let devnull_out = Unix.openfile "/dev/null" [ Unix.O_WRONLY ] 0 in
  let devnull_in = Unix.openfile "/dev/null" [ Unix.O_RDONLY ] 0 in
  (* "dumb" is in every terminfo database, including the minimal ones a
     container ships — the point is a terminal type that always resolves,
     not a capable one. *)
  let screen = Curses.newterm "dumb" devnull_out devnull_in in
  Curses.set_term screen;
  let win = Curses.newwin 4 10 0 0 in
  let wrote = Curses.waddstr win "canary" in
  let rows, cols = Curses.getmaxyx win in
  let deleted = Curses.delwin win in
  Curses.endwin ();
  Curses.delscreen screen;
  Unix.close devnull_out;
  Unix.close devnull_in;
  Printf.printf "ncurses resolved: %s\n" (mapped_path ~prefix:"libncursesw.so.");
  Printf.printf "ncurses tinfo: %s\n" (mapped_path ~prefix:"libtinfo");
  Printf.printf "ncurses window: %dx%d\n" rows cols;
  if wrote && deleted && rows = 4 && cols = 10 then print_endline "ncurses ok"
  else (
    print_endline "MISMATCH: window ops did not behave as declared";
    exit 1)

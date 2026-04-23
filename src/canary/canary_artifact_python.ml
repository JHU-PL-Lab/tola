(* Python package artifact ops.
   A "python artifact" is importable via `python3 -c 'import <pkg>'`.
   No filesystem path to check — the package may live in site-packages,
   a venv, or be installed globally. *)

let python_importable pkg =
  Stdlib.Sys.command
    (Printf.sprintf "python3 -c 'import %s' 2>/dev/null" pkg)
  = 0

(* Python import probe. Writes import.log.
   Output goes to file first, then cat — this preserves python's exit code.
   `| tee` would swallow the exit code (tee returning 0 even when python fails). *)
let python_import_cmd ~pkg ~output_dir =
  [%string
    "python3 -c 'import %{pkg}; print(\"%{pkg} ok\")' \
     > %{output_dir}/import.log 2>&1 && cat %{output_dir}/import.log"]

(* Emit compact Python package summary as summary.json via
   canary/scripts/summarize_python.py. Watchlist is a list of top-level
   attribute names; present/missing recorded in the JSON.
   See doc/canary/python_binding_plan.md. *)
let summary_cmd ~pkg ?(watchlist = []) ~output_dir () =
  let script = "canary/scripts/summarize_python.py" in
  let watchlist_csv = String.concat "," watchlist in
  Printf.sprintf
    "python3 %s --pkg '%s' --watchlist '%s' > %s/summary.json"
    script pkg watchlist_csv output_dir

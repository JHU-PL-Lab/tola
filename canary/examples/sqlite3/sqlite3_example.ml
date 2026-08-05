open Sqlite3

let assert_ok rc = if rc <> Rc.OK then failwith "sqlite3 command failed"

let () =
  (* The RUNTIME library version (whatever .so the loader picked) — canary's
     built-lib worlds repoint the loader (LD_LIBRARY_PATH) and assert this
     line matches the declared built version. *)
  print_endline ("sqlite_version=" ^ sqlite_version_info ());
  let db = db_open ":memory:" in
  assert_ok (exec db "CREATE TABLE t (x INTEGER)");
  assert_ok (exec db "INSERT INTO t VALUES (1)");
  ignore (db_close db);
  print_endline "sqlite3 ok"

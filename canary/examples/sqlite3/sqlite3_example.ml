open Sqlite3

let assert_ok rc = if rc <> Rc.OK then failwith "sqlite3 command failed"

let () =
  let db = db_open ":memory:" in
  assert_ok (exec db "CREATE TABLE t (x INTEGER)");
  assert_ok (exec db "INSERT INTO t VALUES (1)");
  ignore (db_close db);
  print_endline "sqlite3 ok"

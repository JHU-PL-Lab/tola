(* === Syntax === *)
type var = string

(* Terms *)
type term =
  | Var of var
  | Str of string
  | Unit
  | Lam of var * term
  | App of term * term
  | Let of var * term * term
  | Op of string * term (* Effect call *)
  | Handle of string * var * term * term (* handle op => h in t *)
  | Region of string * term (* region r in t *)

(* Values *)
type value = VStr of string | VUnit | VLam of var * term * env
and env = (var * value) list

(* Handlers *)
type handler_ctx =
  (string * (var * term * env)) list (* op -> (arg, handler term, env) *)

type region_ctx = string list

exception RuntimeError of string

(* === Interpreter === *)
let rec lookup_env x env =
  match env with
  | [] -> raise (RuntimeError ("Unbound variable: " ^ x))
  | (y, v) :: rest -> if x = y then v else lookup_env x rest

(* === Example programs === *)
let example1 =
  Region
    ( "r",
      Handle
        ( "Write",
          "s",
          App (Var "log", Var "s"),
          Let
            ( "_",
              Op ("Write", Str "hello"),
              Let ("_", Op ("Write", Str "world"), Unit) ) ) )

let example2 =
  Handle
    ( "Write",
      "s",
      App (Var "log", Var "s"),
      Let ("_", Op ("Write", Str "outside region"), Unit) )

let example3 = Region ("r", Let ("_", Str "no Write here", Unit))

let example4 =
  Handle
    ( "Write",
      "s",
      App (Var "log", Var "s"),
      Let
        ( "_",
          Op ("Write", Str "before region"),
          Region ("r", Let ("_", Op ("Write", Str "inside region"), Unit)) ) )

let example5 =
  Handle
    ( "Write",
      "s",
      App (Var "log", Var "s"),
      Region
        ( "r1",
          Let
            ( "_",
              Op ("Write", Str "in r1"),
              Region ("r2", Let ("_", Op ("Write", Str "in r2"), Unit)) ) ) )

(* Handler for "log" function: prints the string *)
let primitive_env =
  [
    ( "log",
      VLam
        ( "s",
          Lam ("_", Unit),
          [
            ("_", VUnit);
            (* dummy arg *)
            ("s", VStr "") (* replaced at runtime *);
          ] ) );
  ]

(* Override eval to actually print when calling log *)
let rec eval (env : env) (hctx : handler_ctx) (rctx : region_ctx) (t : term) :
    value =
  match t with
  | App (Var "log", Str s) ->
      print_endline ("[log]: " ^ s);
      VUnit
  | App (Var "log", Var x) -> (
      match lookup_env x env with
      | VStr s_val ->
          print_endline ("[log]: " ^ s_val);
          VUnit
      | _ -> raise (RuntimeError "log argument must be a string"))
  | _ -> (
      (* fallback to previous definition *)
      match t with
      | Var x -> lookup_env x env
      | Str s -> VStr s
      | Unit -> VUnit
      | Lam (x, body) -> VLam (x, body, env)
      | App (t1, t2) -> (
          let v1 = eval env hctx rctx t1 in
          let v2 = eval env hctx rctx t2 in
          match v1 with
          | VLam (x, body, clo_env) -> eval ((x, v2) :: clo_env) hctx rctx body
          | _ -> raise (RuntimeError "Attempt to apply non-function"))
      | Let (x, t1, t2) ->
          let v1 = eval env hctx rctx t1 in
          eval ((x, v1) :: env) hctx rctx t2
      | Op (op, arg) -> (
          let v = eval env hctx rctx arg in
          match List.assoc_opt op hctx with
          | Some (x, hterm, henv) -> eval ((x, v) :: henv) hctx rctx hterm
          | None -> raise (RuntimeError ("Unhandled effect: " ^ op)))
      | Handle (op, x, h, body) ->
          let new_hctx = (op, (x, h, env)) :: hctx in
          eval env new_hctx rctx body
      | Region (r, body) ->
          let new_rctx = r :: rctx in
          eval env hctx new_rctx body)

(* === Running === *)
let () =
  print_endline "Running example 1 (with region and handler):";
  ignore (eval primitive_env [] [] example1);
  print_endline "\nRunning example 2 (outside region):";
  ignore (eval primitive_env [] [] example2);
  print_endline "\nRunning example 3 (no Write effect used):";
  ignore (eval primitive_env [] [] example3);
  print_endline "\nRunning example 4 (Write before and inside region):";
  ignore (eval primitive_env [] [] example4);
  print_endline "\nRunning example 5 (nested regions):";
  ignore (eval primitive_env [] [] example5)

(* === Realizability Mapping === *)
(*
Type:             Realizer (program behavior)
----------------+---------------------------------------
T                → any value v
T ⊕ {Write}       → term may invoke Op("Write", ...)
□T               → term must appear under Region r
handle op => h   → installs (op ↦ h) into handler context
*)

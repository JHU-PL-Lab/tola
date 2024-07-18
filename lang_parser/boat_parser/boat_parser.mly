%token <int> INT
%token INPUT
%token <string> ID
%token PLUS
%token LPAREN RPAREN
%token IF0 THEN ELSE
%token FUN GOESTO
%token LET EQUAL IN
%token EOL

/*
 * Precedences and associativities.  Lower precedences come first.
 */
%right prec_let                         /* let f x = ... In ... */
%right prec_fun                         /* fun declaration */
%right prec_if0                         /* if0 ... then ... else */
%left  PLUS                             /* + - */
// See https://stackoverflow.com/questions/27630269/parsing-function-application-with-happy
// This is the Start(expr), but why can't it be computed auto
%nonassoc LPAREN INPUT INT ID
%nonassoc prec_app

%{ open Langs.Lang_boat %}
%start <exp> main

%%

let main :=
  ~ = expr; EOL; <>

let id :=
  // | ~ = ID; <Id>
  | x = ID; {Id x}

let expr := 
  | LPAREN; ~ = expr; RPAREN; <>
  | INPUT; { Input }
  | ~ = INT; <Int>
  | e1 = expr; PLUS; e2 = expr; <Plus>
  | IF0; e1 = expr; THEN; e2 = expr; ELSE; e3 = expr; %prec prec_if0 <If0>
  | ~ = id; <Var>
  | FUN; ~ = id; GOESTO; ~ = expr; %prec prec_fun <Fun>
  | LET; ~ = id; EQUAL; e1 = expr; IN; e2 = expr; %prec prec_let <Let>
  | e1 = expr; e2 = expr; %prec prec_app <App>
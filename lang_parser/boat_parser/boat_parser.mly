%token <int> INT
%token INPUT
%token <string> IDENT
%token PLUS
%token LPAREN RPAREN
%token IF0 THEN ELSE
%token FUN
%token LET IN
%token EOL

/*
 * Precedences and associativities.  Lower precedences come first.
 */
%right prec_let                         /* Let Rec f x = ... In ... */
%right prec_fun                         /* function declaration */
%right prec_if0                         /* If0 ... Then ... Else */
%left  PLUS                             /* + - */

%{ open Langs.Lang_boat %}
%start <exp> main

%%

let main :=
  ~ = expr; EOL; <>

let expr := 
  | LPAREN; ~ = expr; RPAREN; <>
  | INPUT; { Input }
  | ~ = INT; <Int>
  | e1 = expr; PLUS; e2 = expr; <Plus>
  | IF0; e1 = expr; e2 = expr; e3 = expr; %prec prec_if0 <If0>

let id :=
  | ~ = IDENT; <Id>

/* | simple_expr


| ~ = expr; PLUS; ~ = expr; <Plus>

let simple_expr :=
| LPAREN; ~ = expr; RPAREN; <>
*/
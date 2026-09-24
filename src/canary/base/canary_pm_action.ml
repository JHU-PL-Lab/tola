(** WHAT A PACKAGE MANAGER DOES INSIDE ONE OF OUR ACTIONS (2026-09-23,
    status.md §2.7 E).

    [fetch_lib] is one action to canary and several to apt: choose a
    version, fetch it, unpack it. [fetch_binding_ocaml] is one action to
    canary and, to opam, a solve over the whole dependency set, a build of
    every package it installs — a bridge package's build being the moment
    the bridge's check runs — and an install. Most of that goes
    unrecorded. This names it, per package manager, so that each piece
    canary does not record gets a PLACEHOLDER STEP: a step that does no
    work, holds its place in the action graph, and says why it is empty
    (user, 2026-09-23: "we can have placeholder actions, then in a detail
    action log or diagram, we can use special node to show not-implemented
    yet").

    Two reasons, and they are different kinds of gap. [Not_yet]: the fact
    is retrievable and nobody has written the recording — the placeholder
    says how. [Out_of_reach]: the tool does not expose it — the placeholder
    says why, so it stops looking like a to-do.

    A placeholder is NOT a dummy ([Canary_step_builder.Dummy]). A dummy
    asserts there is nothing to do; a placeholder asserts there is
    something, done by somebody else, that canary does not see.

    This is the seed of a PM-SOLO catalogue in the sense of the layered
    model: what one package manager's action consists of inside, the way
    [Canary_mechanism] says what a binding consists of. Only what the
    placeholders need is here. *)

open Base

(** A piece of a package manager's action. *)
type does =
  | Resolve  (** choose a version of every package the request needs *)
  | Build_package
      (** build a package from its source, inside the package manager: its
          configure — where it asks pkg-config for the library — then its
          compile and its link *)
[@@deriving show, eq]

(** Why canary does not record it. *)
type unseen =
  | Not_yet of string  (** retrievable; how it could be recorded *)
  | Out_of_reach of string
      (** the tool does not expose it; why, from outside, it cannot be *)
[@@deriving show, eq]

type placeholder = {
  ph_pm : Canary_store.package_manager;
  ph_key : string;  (** short and stable: it names the step *)
  ph_does : does;
  ph_what : string;  (** what exactly goes unrecorded *)
  ph_unseen : unseen;
}

let string_of_does = function
  | Resolve -> "resolve"
  | Build_package -> "build_package"

(** The word a record and a view carry for the reason. *)
let code_of_unseen = function Not_yet _ -> "not_yet" | Out_of_reach _ -> "out_of_reach"

(** The reason as a sentence. *)
let string_of_unseen = function
  | Not_yet how -> "not recorded yet — " ^ how
  | Out_of_reach why -> "out of reach — " ^ why

let describe (p : placeholder) : string =
  Printf.sprintf "%s %s: %s; %s"
    (Canary_store.string_of_pm p.ph_pm)
    (string_of_does p.ph_does) p.ph_what (string_of_unseen p.ph_unseen)

(** What goes unrecorded inside an install by [pm] — of a library, or of
    a binding ([~of_binding]), which opam builds from source. The list is
    what the placeholder steps stand for; a piece canary starts recording
    leaves the list in the same change. *)
let inside_install (pm : Canary_store.package_manager) ~(of_binding : bool) :
    placeholder list =
  let ph ph_key ph_does ph_what ph_unseen =
    { ph_pm = pm; ph_key; ph_does; ph_what; ph_unseen }
  in
  match pm with
  | Canary_store.Apt ->
      [ ph "policy" Resolve
          "the version apt chose, and the pins and priorities that chose it"
          (Not_yet "`apt-cache policy <package>` answers both, in the world \
                    the run is in") ]
  | Canary_store.Brew ->
      [ ph "policy" Resolve "the formula version brew chose"
          (Not_yet "`brew info --json=v2 <formula>` gives the installed and \
                    the available versions") ]
  | Canary_store.Opam ->
      [ ph "plan" Resolve
          "the plan opam carried out: each package it installed, rebuilt or \
           removed — a bridge package among them, whose build is when the \
           bridge's check runs"
          (Not_yet "the install prints one line per package (`∗ installed \
                    conf-gmp.5`), or that the package is already installed \
                    and nothing was done");
        ph "solver" Resolve "why opam's solver chose these versions"
          (Out_of_reach "opam reports the solution it reached, not the search \
                         that reached it") ]
      @ (if of_binding then
           [ ph "build" Build_package
               "the package's own build inside opam: its configure, where it \
                asks pkg-config for the library, then its compile and link"
               (Not_yet "opam deletes the build directory when the build \
                         succeeds; installing with --keep-build-dir keeps the \
                         configure output and the compile commands") ]
         else [])
  | Canary_store.Pip ->
      [ ph "plan" Resolve
          "the distributions pip installed, and whether each came as a wheel \
           or was built from source"
          (Not_yet "pip's output names each one (`Successfully installed`, \
                    `Building wheel for`)");
        ph "solver" Resolve "why pip's resolver chose these versions"
          (Out_of_reach "pip reports the versions it chose, not how it chose \
                         them") ]
  | Canary_store.Unsupported -> []

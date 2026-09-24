(** A BRIDGE IS A THING (2026-09-23, user; status.md §2.7 E, decisions 1
    and 2).

    Package content that exists for cooperation BETWEEN two package
    managers. [conf-gmp] is an opam package somebody wrote so that an opam
    package can reach a system one; it belongs to neither the pure native
    side nor the pure language side, which is why a binding-level view
    cannot see it.

    Three decisions shape the type:

    - it is a THING, not a relation — a node on the overview's graph, with
      state a tool can be asked about: is it installed, at which version,
      what does it map to, what does its check answer;
    - each package manager defines its OWN kinds, so the type is a variant
      per package manager. opam has two; a Cargo [*-sys] crate would be
      Cargo's. There is one package manager here today because only opam
      bindings declare a bridge;
    - it is kept APART from what every package manager has — install,
      remove, ask for a version ([Canary_pm_opam] and its siblings) —
      because its reason to exist is the OTHER package manager. The tool
      layer's driver for it is [Canary_bridge_driver].

    Two things that are NOT here, both on purpose:

    - a CAPABILITY FILE. [gmp.pc] belongs to the package that ships it
      ([libgmp-dev]), faces the artifacts, and is a source of claims; a
      conf package's check READS it. It was a third constructor of the
      topology's bridge type until this module replaced that type;
    - the CONSTRAINT on a bridge. [conf-libffi {>= "2.0.0"}] is the binding
      package's [depends] edge TO the bridge, and it stays on that edge —
      [Canary_binding_decl.pm_dep_gate]. *)

open Base

(** opam's bridge kinds. *)
type opam =
  | Conf_package of string
      (** a [conf-*] package. Its [build:] field runs a check against the
          system — the PREDICATE — and its [depexts:] field maps it to
          system package names. [conf-gmp]. *)
  | Depext_field of string
      (** the binding package's own [depexts:] entry, with no conf hop:
          metadata inside the consumer rather than a package of its own.
          torch's [libtorch]. It carries no check. *)
[@@deriving show, eq]

type t = Opam of opam [@@deriving show, eq]

let pm_of : t -> Canary_store.package_manager = function
  | Opam _ -> Canary_store.Opam

(** The bridge KINDS a package manager defines: per constructor of that
    manager's variant, its TERM — the short name the overview writes under
    its "bridge package" node (user, 2026-09-24: "show the terms in that
    pm in the next line") — and what it is. A manager that defines none
    (apt, brew, pip) has an empty list. *)
let kinds_defined : Canary_store.package_manager -> (string * string) list = function
  | Canary_store.Opam ->
      [ ("conf-* package", "a check plus a depext mapping");
        ("depext field", "the binding package names the system package itself") ]
  | Canary_store.Apt | Canary_store.Brew | Canary_store.Pip | Canary_store.Unsupported ->
      []

(** The kinds, as the PM-solo table shows them. *)
let kinds_of_pm (pm : Canary_store.package_manager) : string list =
  List.map (kinds_defined pm) ~f:(fun (term, what) -> term ^ ": " ^ what)

(** The TERM for one bridge's kind — one of [kinds_defined]'s, which
    [overview.chain_choices_draw_one_chain] holds it to. *)
let kind_term : t -> string = function
  | Opam (Conf_package _) -> "conf-* package"
  | Opam (Depext_field _) -> "depext field"

(** The package that IS the bridge, or that carries it. *)
let package_of : t -> string = function
  | Opam (Conf_package p) | Opam (Depext_field p) -> p

let to_string : t -> string = function
  | Opam (Conf_package p) -> p
  | Opam (Depext_field d) -> "depext:" ^ d

(** Does the bridge carry a CHECK against the system — the half of it
    that validates the symbolic mapping against artifacts? A conf package
    always does; that is what [flags: conf] marks. A depext field is a
    mapping and nothing else. *)
let has_check : t -> bool = function
  | Opam (Conf_package _) -> true
  | Opam (Depext_field _) -> false

(** The bridge a binding's package gate names, if it names one. Four of
    the gate's six cases describe the [depends] edge TO a bridge. The
    other two, [Package_builds_lib] and [Bundled], are package-specific
    rewrites that remove the provider ecosystem, so there is no bridge
    for them to name. *)
let of_gate : Canary_binding_decl.pm_dep_gate -> t option = function
  | Canary_binding_decl.Free_with_conf conf
  | Canary_binding_decl.Bounded_with_conf { conf; _ }
  | Canary_binding_decl.Fixed_with_conf { conf; _ } ->
      Some (Opam (Conf_package conf))
  | Canary_binding_decl.Pinned_depext { depext; _ } ->
      Some (Opam (Depext_field depext))
  | Canary_binding_decl.Package_builds_lib | Canary_binding_decl.Bundled _ ->
      None

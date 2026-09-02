(** The check CATEGORY — descriptive (user, 2026-09-02).

    A category says what kind of claim a check makes. Nothing dispatches
    on it: it groups the catalogue, the checking index and the doc, and
    it is deliberately allowed to refine as checks accumulate, because a
    descriptive type costs nothing to sharpen.

    It is NOT the check's signature. Checks keep whatever signature suits
    them — a symbol comparison and a repo-pin query have no reason to
    agree — and the caller supplies the inputs and decides where to dump
    the evidence on failure. *)

type cat =
  | Symbols   of [ `Exported | `Required | `Versioned | `Orphan ]
  | Api       of [ `Present | `Complete | `Repacked ]
  | Identity  of [ `Soname | `Version_node ]
  | Types     of [ `Signature | `Arity ]
  | Behaviour of [ `Trace | `Differential ]
  | Repo      of [ `Pin | `Freshness | `Contents ]
  | Staging   of [ `Completeness | `Parity | `Portability ]
  | Action_succeeded
      (** the weakest claim available: the tool did not error, and its
          declared output appeared. No artifact is read — which is why
          §1.1 says to inspect the product wherever one exists. Free at
          every action, and it is what a later blame step has to start
          from. *)
  | Meta      of [ `Spec | `Framework ]
      (** about canary's own declarations rather than the tools' *)

let string_of_cat = function
  | Symbols `Exported -> "symbols/exported"
  | Symbols `Required -> "symbols/required"
  | Symbols `Versioned -> "symbols/versioned"
  | Symbols `Orphan -> "symbols/orphan"
  | Api `Present -> "api/present"
  | Api `Complete -> "api/complete"
  | Api `Repacked -> "api/repacked"
  | Identity `Soname -> "identity/soname"
  | Identity `Version_node -> "identity/version-node"
  | Types `Signature -> "types/signature"
  | Types `Arity -> "types/arity"
  | Behaviour `Trace -> "behaviour/trace"
  | Behaviour `Differential -> "behaviour/differential"
  | Repo `Pin -> "repo/pin"
  | Repo `Freshness -> "repo/freshness"
  | Repo `Contents -> "repo/contents"
  | Staging `Completeness -> "staging/completeness"
  | Staging `Parity -> "staging/parity"
  | Staging `Portability -> "staging/portability"
  | Action_succeeded -> "action-succeeded"
  | Meta `Spec -> "meta/spec"
  | Meta `Framework -> "meta/framework"

(** Is this agreement a CONVENTION — true of every project using the
    toolchain, declared by nobody (a findlib META naming an archive that
    exists, a wheel's EXT_SUFFIX matching its interpreter)? A marker, not
    a separate source: conventions are agreements that happen to be
    obligatory and project-independent, which makes them the richest
    place to look for new checks. *)
type standing = Declared | Convention

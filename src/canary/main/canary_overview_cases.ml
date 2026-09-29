(** The five hand-drawn cases, one per cooperation: the prose §1 shows with
    the cooperation it illustrates, and the oracle the pins hold the
    derivations to — each case's names, the nodes it leaves out and the
    edges it greys ([overview.package_band_is_one_cooperation],
    [overview.recorded_views_are_named]). *)

module T = Canary_topology

(** One hand-drawn case. *)
type case = {
  ca_key : string;
  ca_coop : T.coop;  (** the cooperation it illustrates *)
  ca_title : string;
  ca_blurb : string;
  ca_names : (string * string) list;  (** node id → what the case calls it *)
  ca_subs : (string * string) list;  (** node id → what the case says about it *)
  ca_hidden : string list;  (** nodes that do not exist in the case *)
  ca_dead : string list;  (** edges that exist and do not fire *)
}

let hand_cases : case list =
  [ { ca_key = "conf"; ca_coop = T.Co_conf; ca_title = "conf-* over a system library";
      ca_blurb =
        "Both bridges present, and each sits with its author. The \
         SYMBOLIC path runs <code>binding → conf → depext → system \
         package</code>; the ARTIFACT path runs <code>conf predicate → \
         capability query → the library on disk</code>. They can land \
         on different libraries, and nothing today compares them.";
      ca_names =
        [ ("pm_sys", "apt"); ("pkg_sys", "libgmp-dev");
          ("bridge", "conf-gmp"); ("cap", "gmp.pc"); ("pm_lang", "opam");
          ("pkg_lang", "zarith"); ("lib_sys", "libgmp.so.10");
          ("hdr_sys", "gmp.h"); ("src_lang", "Zarith.git");
          ("stub_lang", "zarith_stubs.a"); ("mod_lang", "zarith.cmxa");
          ("surf_lang", "zarith.mli");
          ("consumer_artifact", "zarith_example (paths)");
          ("consumer_package", "zarith_example (-package zarith)") ];
      ca_subs =
        [ ("bridge", "an opam package — written by an opam maintainer");
          ("cap", "inside libgmp-dev — written by the Debian packager") ];
      ca_hidden = [ "src_sys"; "staged_sys" ]; ca_dead = [] };
    { ca_key = "wheel"; ca_coop = T.Co_absorbed; ca_title = "the library inside the wheel";
      ca_blurb =
        "The consumer package carries the native artifact. The system \
         PM, the system package and <em>both</em> bridges disappear — \
         there is no cooperation left, which is a different statement \
         from having no bridge. Every claim that compared two \
         ecosystems has nothing to compare.";
      ca_names =
        [ ("pm_lang", "pip"); ("pkg_lang", "z3-solver (wheel)");
          ("lib_sys", "libz3.so — INSIDE the wheel");
          ("mod_lang", "z3/*.py + native ext");
          ("surf_lang", "z3.__all__");
          ("consumer_package", "python -c 'import z3'") ];
      ca_subs =
        [ ("lib_sys", "no system package, no bridge, no discovery");
          ("pkg_lang", "one package supplies both sides") ];
      ca_hidden =
        [ "pm_sys"; "pkg_sys"; "bridge"; "cap"; "src_sys"; "staged_sys";
          "hdr_sys"; "src_lang"; "stub_lang" ];
      ca_dead = [] };
    { ca_key = "built"; ca_coop = T.Co_gated_local;
      ca_title = "built here — and the bridge still gates";
      ca_blurb =
        "The native side is built here, so the system package is not \
         used. The binding package's <code>conf-llvm-shared {= \
         \"19\"}</code> constraint is still in its depends and opam \
         still evaluates it — against the system, which this world is \
         not using. The gate passes or fails on evidence unrelated to \
         the artifacts under test.";
      ca_names =
        [ ("src_sys", "llvm-project @ ref");
          ("lib_sys", "libLLVM.so (built)");
          ("staged_sys", "install prefix");
          ("pm_sys", "apt — not used here");
          ("pkg_sys", "llvm-19-dev — not used here");
          ("bridge", "conf-llvm-shared {= 19}"); ("cap", "llvm-config");
          ("pm_lang", "opam"); ("pkg_lang", "llvm.19-shared");
          ("mod_lang", "llvm.cmxa");
          ("consumer_artifact", "llvm_example (build tree)");
          ("consumer_package", "llvm_example (-package llvm)") ];
      ca_subs =
        [ ("bridge", "still runs — against the SYSTEM, not this build");
          ("pkg_sys", "the gate validates this, the world uses that") ];
      ca_hidden = [];
      ca_dead = [ "resolve_sys"; "realize_sys"; "realize_hdr"; "realize_cap" ] };
    { ca_key = "unified"; ca_coop = T.Co_unified; ca_title = "one package universe";
      ca_blurb =
        "Both sides come from the same package manager, so there is no \
         second ecosystem to bridge to — the constraint travels as an \
         ordinary dependency in one namespace. This is torch: the \
         library arrives through opam as an upstream binary, named \
         directly by a depext bound rather than through a conf hop.";
      ca_names =
        [ ("pm_lang", "opam"); ("pkg_lang", "torch");
          ("bridge", "depext: libtorch >=2.1.0 <2.2.0");
          ("lib_sys", "libtorch.so (opam binary)");
          ("hdr_sys", "torch/*.h"); ("src_lang", "ocaml-torch.git");
          ("stub_lang", "libtorch_core_stubs.a");
          ("mod_lang", "torch.cmxa"); ("surf_lang", "torch.mli");
          ("consumer_artifact", "torch_example (paths)");
          ("consumer_package", "torch_example (-package torch)") ];
      ca_subs =
        [ ("bridge", "metadata inside the consumer — not a package of its own");
          ("pkg_lang", "same PM on both sides") ];
      ca_hidden = [ "pm_sys"; "pkg_sys"; "cap"; "src_sys"; "staged_sys" ];
      ca_dead = [] };
    { ca_key = "none"; ca_coop = T.Co_no_pm; ca_title = "no package manager between them";
      ca_blurb =
        "The binding and the library were joined by whoever built the \
         interpreter, outside any package manager we can observe. \
         CPython's stdlib <code>sqlite3</code> is the case. The \
         coupling is entirely real — the extension records a NEEDED on \
         libsqlite3 and the loader resolves it — but there is no \
         declaration anywhere to check it against. <em>No gate</em> and \
         <em>no gate mechanism</em> are different situations.";
      ca_names =
        [ ("pm_sys", "apt"); ("pkg_sys", "libsqlite3-0");
          ("lib_sys", "libsqlite3.so.0"); ("hdr_sys", "sqlite3.h");
          ("pm_lang", "(the interpreter build)");
          ("pkg_lang", "CPython stdlib");
          ("stub_lang", "_sqlite3.cpython-*.so");
          ("mod_lang", "sqlite3/__init__.py");
          ("surf_lang", "dir(sqlite3)");
          ("consumer_package", "python -c 'import sqlite3'") ];
      ca_subs =
        [ ("pkg_lang", "chosen at interpreter build time, not here");
          ("lib_sys", "the loader picks it; nothing declared which") ];
      ca_hidden = [ "bridge"; "cap"; "src_sys"; "staged_sys"; "src_lang" ];
      ca_dead = [] } ]

open Base

(* ── Package managers and locations ──
   A store is any place artifacts can be fetched from or published to.
   Location identifies where an artifact physically resides. *)

(* PM-related types (inlined from canary_pm_types.ml on 2026-06-01,
   Phase 10a). The separate file existed only because canary_store and
   the per-PM drivers needed shared types without a circular dep —
   now that the dispatchers (pm_install_cmd etc.) live in
   tool/canary_pm.ml (Phase 9a), no cycle remains. *)

type package_manager = Apt | Brew | Opam | Pip | Unsupported
type store_behavior = Stateless | Stateful_global | Isolated_store of string
type pm_scope = System | Lang

type pm_properties = {
  pm : package_manager;
  scope : pm_scope;
  behavior : store_behavior;
  switching : string;
  parallel_safe : bool;
}

(* How a consumer's RUNTIME provider relates to the enumerated placement —
   the runtime-coupling analogue of [provision] (which is about how an
   artifact is PROVIDED at build/fetch time). Base vocabulary since
   2026-08-05 (was action-layer only, on [close_deps]); the action layer
   re-exports it, and a project declares it per-ARTIFACT in its spec axes
   ([Canary_artifact.artifact_axes]).
   - [Lockstep]    — run provider = build provider (the matched chain).
   - [Independent] — the run provider is whatever the scenario places,
                     independent of the consumer's own build-time provider
                     (run-lib ≠ build-lib = the deploy pairing).
   - [Ambient s]   — the run provider is outside the enumeration entirely
                     (a bundled/co-provider lib, the system libc, …);
                     [s] names it for display. *)
type dep_mode = Lockstep | Independent | Ambient of string
[@@deriving show, eq]

type system_package_spec = {
  linux_pkg : string;
  macos_pkg : string;
  version_tag : string option;
  locator_hint : string option;
  behavior : store_behavior;
}

(* pm_info: what kind of package manager location.
   Sys_pm: system PM (apt/brew) — native C lib; pm distinguishes linux vs macOS.
   Lang_pm: language PM (opam/pip) — binding artifact; carries lang + pm.
   Future variants: Virtual_pm, Project_pm, Multi_lingua_pm, … *)
type pm_info =
  | Sys_pm of { pm : package_manager }
  | Lang_pm of { lang : Canary_lang.lang; pm : package_manager }

(* Location: objective "where does this artifact live right now".
   Build_tree: raw build output. Staged: cmake --install'd (TODO #25).
   Pm: in a package manager — see pm_info for the sub-kind. *)
type location =
  | Build_tree
  | Staged  (** cmake --install'd into a prefix — see TODO #25 *)
  | Pm of pm_info

(* Artifact status — the lifecycle state of an artifact (explicit
   complement to location). Renamed from [stage] on 2026-07-21 per
   SSOT §6.2 so [stage] is free for pipeline-phase meaning (Sc.N
   is-a stage). Derivable from location for now (Build_tree→Built,
   Staged→Installed, Pm→Packed or Fetched).

   Planned: a first-class [artifact_details] record pairing this with
   [provision] and [location] — two axes, one for origin, one for
   whereabouts:
     - [provision]              = where the artifact came FROM (how it was
                                  created / blame; fixed once it exists).
     - [artifact_status] + [location] = where it is NOW (moves as it is
                                  installed / packed / fetched).
   Deferred until a consumer needs provenance/blame tracking — not
   enumeration-related, so no type yet. *)
(* [Installed_state] (2026-08-18): renamed from [Installed] so the
   dormant lifecycle constructor yields the name to the provision
   below — the ACTIVE axis (zero consumers of the status type). *)
type artifact_status = Built | Installed_state | Packed | Fetched

(** Provenance of an artifact — the *provision* coordinate (ssot §4.2):
    which store provides it in a scenario. [Absent] (not provided) ·
    [Fetched] (from a PM) · [Built] (from source) · [Installed] (built,
    then staged into the install prefix — the consumer-facing face of a
    Built artifact; 2026-08-18, the provider-exclusive-rows model) ·
    [Vendored] (a supplied copy at a path, local *or* remote — not built
    here, not PM-resolved).

    Distinct axis from [artifact_status] above: provision is the *choice of
    source*; artifact_status is the *lifecycle state* an artifact reaches
    (Built → Installed_state → Packed → Fetched). The shared
    [Built]/[Fetched] names are intentional — a [Built] provision lands in
    the Built state, a [Fetched] provision in the Fetched state. *)
type provision = Absent | Fetched | Built | Installed | Vendored
[@@deriving show, eq]

let string_of_provision = function
  | Absent -> "absent"
  | Fetched -> "fetched"
  | Built -> "built"
  | Installed -> "installed"
  | Vendored -> "vendored"

let string_of_pm = function
  | Apt -> "apt"
  | Brew -> "brew"
  | Opam -> "opam"
  | Pip -> "pip"
  | Unsupported -> "unsupported"

let string_of_store_behavior = function
  | Stateless -> "stateless"
  | Stateful_global -> "stateful-global"
  | Isolated_store name -> [%string "isolated(%{name})"]

let string_of_location = function
  | Build_tree -> "build_tree"
  | Staged -> "staged"
  | Pm (Sys_pm { pm }) -> [%string "sys_pm:%{string_of_pm pm}"]
  | Pm (Lang_pm { lang; pm }) ->
      [%string "%{Canary_lang.string_of_lang lang}:%{string_of_pm pm}"]

let is_source_location = function
  | Build_tree | Staged -> true
  | Pm _ -> false

(* Placeholder location for universal action-action enumeration (canary paths). *)
let store = Pm (Sys_pm { pm = Apt })


let store_behavior_of_pm = function
  | Apt | Brew -> Stateful_global
  | Opam -> Isolated_store "switch"
  | Pip -> Isolated_store "venv"
  | Unsupported -> Stateless

let mk_system_package_spec ?version_tag ?locator_hint
    ?(behavior = Stateful_global) ~linux_pkg ~macos_pkg () =
  { linux_pkg; macos_pkg; version_tag; locator_hint; behavior }

let system_pkg_for_pm spec pm =
  match pm with
  | Brew -> spec.macos_pkg
  | Apt | Opam | Pip | Unsupported -> spec.linux_pkg

(* The PM dispatchers (pm_install_cmd, system_install_cmd,
   verify_system_install_cmd) moved to tool/canary_pm.ml on 2026-06-01
   (Phase 9a) to fix the base→tool layer reversal. The per-PM drivers
   live in tool/canary_pm_{apt,brew,opam,pip}.ml; their dispatcher
   belongs next to them, not here. base/canary_store keeps only types
   and pure helpers. *)

(* ── Distro ──
   Cross-cutting: affects both source local-path lookup and system PM
   (apt on Linux, brew on macOS). Kept here since it's used by both
   the PM dispatch above and the source artifact module. *)

type distro = Wsl | MacOS_local

let distro_base : distro -> string = function
  | Wsl -> "/home/red/code"
  | MacOS_local -> "/Users/ex/code"

(* THE contrib root (2026-08-15, design/enumeration/stage1_declare_spec.md): the shared
   third-party checkout tree — a base-layer SETTING (data in code; the
   user's decision — no config files in contrib, see its README; other
   projects decide their own layout). The convention:
   <contrib_root>/<project>-all/<repo-name>. *)
let contrib_root : distro -> string = fun d -> distro_base d ^ "/contrib"

let all_distros = [ Wsl; MacOS_local ]

(* ── THE PLATFORM (2026-08-26, user: "the canary config should carry the
      platform argument") ──────────────────────────────────────────────

   ONE VALUE, SET ONCE, ASKED EVERYWHERE. Before this there were THREE
   independent detectors — [Canary_basic.detect_distro] (uname),
   [detect_pm] below (which brew / which apt-get) and
   [Canary_artifact_native.is_macos] (uname again) — each re-probing on
   demand, and they could DISAGREE. The concrete hazard was not
   hypothetical: [detect_pm] tried brew FIRST, so a Linux box with
   Linuxbrew installed answered [Brew] while the distro answered [Wsl],
   and [system_pkg_for_pm] would then pick the macOS package name on
   Linux. A platform is one fact about one machine; deriving the package
   manager FROM it, rather than sniffing for it separately, makes that
   class of disagreement unrepresentable.

   [distro] is that fact — it was already the codebase's name for "which
   machine", carrying the per-machine home in [distro_base]. It is not
   re-detected per call: the probe runs at most once and the answer is
   held, so [spec]/[paths]/[graph] pay one [uname] rather than one per
   consulting site.

   OVERRIDABLE, because the entry point owns it. [set] lets the CLI
   ([--platform=macos]) or a test fix the value before anything reads it;
   it is the same shape as the opam-switch selection above and is
   reported the same way (the run header and actions.log both name it),
   so a run always says which platform it believed it was on. *)

let platform_of_string = function
  | "macos" | "macos_local" | "darwin" -> Some MacOS_local
  | "wsl" | "wsl_ubuntu" | "linux" | "ubuntu" -> Some Wsl
  | _ -> None

let string_of_platform = function
  | Wsl -> "wsl_ubuntu"
  | MacOS_local -> "macos_local"

let detected_platform =
  lazy
    (match Stdlib.Sys.command "uname -s 2>/dev/null | grep -q Darwin" with
    | 0 -> MacOS_local
    | _ -> Wsl)

let platform_override : distro option ref = ref None

(** THE platform this run is about. *)
let platform () : distro =
  match !platform_override with
  | Some d -> d
  | None -> Lazy.force detected_platform

(** Fix the platform explicitly (CLI / tests). Call before anything reads
    it — the value is not cached downstream, but a project spec built
    from the old answer would not be rebuilt. *)
let set_platform (d : distro) : unit = platform_override := Some d

(** Is the platform an explicit choice rather than what [uname] said? *)
let platform_is_overridden () : bool = Option.is_some !platform_override

(* ── System package manager, DERIVED from the platform ── *)

(** The system package manager a platform uses. Not a probe: on macOS it
    is brew, on our Linux it is apt. If the tool is missing that is an
    environment error to report, not a different platform to infer —
    inferring is what let Linuxbrew masquerade as macOS. *)
let system_pm_of_platform = function
  | MacOS_local -> Brew
  | Wsl -> Apt

let detect_pm () = system_pm_of_platform (platform ())

(* Source repo and its operations moved to canary_artifact_source.ml *)

(* ── THE OPAM SWITCH CANARY OPERATES IN (2026-08-26, user) ──

   Canary mutates the opam store as a matter of course: every
   [fetch_binding] installs a package, and a binding channel pair is
   realized by FLIPPING a pin, which opam can only do by uninstalling the
   other version (one version per switch — see
   project/opam_exclusive_store_issue.md). Measured, that is destructive
   in proportion to the package: zlib/cairo cost one downgrade, libffi
   two plus three recompiles, and zstd removes [ocaml-compiler] and
   recompiles 157 packages. Doing that to the switch a person WORKS in is
   not acceptable, which is why the binding axis on the template projects
   sat blocked (project/status_project.md §1 E).

   So canary targets a switch of its own. The mechanism is deliberately
   the smallest one that works: every shell command canary runs already
   begins with [eval $(opam env)], and [opam env] honours OPAMSWITCH — so
   exporting it once, in the one place every command is executed
   ([Canary_local_runner.run_cmd_logged]), redirects all of them without
   touching a single command template. A name that does not exist is an
   opam ERROR rather than a silent fallback, which is the failure mode we
   want.

   [None] means "whatever switch is ambient" — the pre-2026-08-26
   behaviour, kept so a person can still point canary at their own switch
   deliberately.

   WHICH switch is the default is a MACHINE fact, not a framework one
   (2026-08-26 evening, user: "let's just use the default opam", starting
   the macOS run). [distro] is already this codebase's proxy for "which
   machine" — [distro_base] is a per-machine home — so the default
   follows it: the WSL box has the dedicated [canary] switch built for it
   and keeps it; the mac has no such switch and runs in whatever is
   ambient. The three properties the mechanism was pinned on are
   untouched — an explicit [--switch=NAME] / [CANARY_SWITCH] still wins,
   the switch is still in the step fingerprint, and the run header still
   names it, so the per-machine difference is VISIBLE rather than
   silent. *)

(* Which switch a run defaults to, per machine: the box with a dedicated
   [canary] switch gets it; the mac, which has none, runs ambient.

   READS [detected_platform] (2026-08-26). It used to run its own
   [uname] — a fourth sniff, seventy lines below the value that had just
   replaced three of them. The comment justifying the copy cited a layer
   inversion with [Canary_basic.detect_distro], which is a module ABOVE
   this one; it does not apply to the lazy defined right here.

   [detected_platform], NOT [platform ()], and the distinction is the
   point: [--platform=macos] is a RENDERING choice — it says "show me
   what the mac would do" — and it must not repoint the store this
   machine installs into. What switch to mutate is a fact about the box;
   what platform to render is a fact about the request.

   Stated honestly: that distinction is not OBSERVABLE today, so no test
   pins it. The lazy is forced by [opam_switch] below, at module
   initialization — before the CLI has parsed anything — so [platform ()]
   would return the detected value anyway and memoize it. The two spell
   the same answer, and only one of them stays right if this is ever
   forced later. [default_switch_of] is the falsifiable half: the mapping
   itself, pinned in [platform.single_source]. *)
let default_switch_of : distro -> string option = function
  | MacOS_local -> None (* no dedicated switch there — run ambient *)
  | Wsl -> Some "canary"

let default_opam_switch : string option Lazy.t =
  lazy (default_switch_of (Lazy.force detected_platform))

let opam_switch : string option ref = ref (Lazy.force default_opam_switch)

(** The shell prologue that puts a command in canary's switch. Empty when
    no switch is selected, so the ambient behaviour is byte-identical. *)
let opam_switch_prologue () : string =
  match !opam_switch with
  | None -> ""
  | Some s -> Printf.sprintf "export OPAMSWITCH=%s\n" (Stdlib.Filename.quote s)

(** How the switch appears in a fingerprint / a run header. *)
let opam_switch_label () : string =
  match !opam_switch with None -> "(ambient)" | Some s -> s

(** Run a shell command FROM OCAML in the selected switch, and return its
    exit code.

    THE SECOND CHOKE POINT (2026-08-26). {!opam_switch_prologue} was
    applied in [run_cmd_logged] only — the point every STEP's command goes
    through. But canary also shells out from OCaml, outside any step:
    [pin_check_post] asks whether the switch holds the pin, [is_installed]
    asks whether a package is there. Those calls are plain [Sys.command],
    so they inherit the process environment — which has no [OPAMSWITCH] —
    and answered about the AMBIENT switch while the step they were
    certifying ran in canary's.

    Measured on WSL (sqlite, 2026-08-26): five scenarios installed
    [sqlite3.5.1.0] into the [canary] switch, and [pin_check_post] then
    read [5.4.1] out of [default] and failed the fetch. The other five
    passed for the same reason — [default] happened to hold [5.4.1] — so
    the green cells were as wrong as the red ones, they just looked
    right. That is the same class the switch work exists to close: a
    verdict about a store nobody under test was using.

    Not folded into the [Canary_pm_opam] command builders on purpose:
    those strings are also EMITTED into step shell (which already carries
    the prologue), and changing them would change the step fingerprint and
    re-run every pinned world for no reason. The prologue belongs to
    RUNNING a command from OCaml, so it lives on the runner. *)
let sh_in_switch (cmd : string) : int =
  Stdlib.Sys.command (opam_switch_prologue () ^ cmd)

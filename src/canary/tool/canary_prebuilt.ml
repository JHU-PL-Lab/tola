(** [Canary_prebuilt] — prebuilt native libs fetched from OUTSIDE the
    system package manager (2026-08-19, user).

    THE PROBLEM this solves. A project's lib axis needs a stable/latest
    pair, and for most C libraries the distro ships exactly ONE version
    (measured: apt has one each of gmp / openssl / libffi / cairo). The
    other point has to come from somewhere else, and building from source
    is deliberately a last resort (the prebuilt-shadows-source rule).

    THE SOURCING RULE (project/landing.md §3):
    1. stable = the system PM — what users actually link against;
    2. latest = the project's OWN prebuilt download, when it publishes
       one for our platform (authoritative);
    3. latest = conda-forge's newest versioned release otherwise —
       measured 2026-08-19: no Linux C library in our set publishes an
       official binary, so step 3 is the usual answer.

    THE PROVISION IS [Vendored]. A downloaded prebuilt is a SUPPLIED
    artifact: canary neither built it nor asked a PM to resolve it. That
    is exactly what [Vendored] means, so no new provision (and no new
    enumeration axis) is needed — [shadow_filter] already treats Vendored
    as prebuilt, [scenario_dir_of] renders `lib-vendored-<chan>`, and the
    matrix prints `V:d`.

    IT IS PREPARED, NOT RUN. Like tiny's vendored artifacts, the download
    happens BEFORE any enumeration or checking run (`canary prebuilt`), so
    a run never depends on the network for it and every scenario sees the
    same bytes. *)

open Base

(** What to fetch for ONE platform (2026-08-26). A prebuilt is a
    downloaded BINARY, so both halves of it are platform-specific: the
    archive (conda-forge builds [linux-64] and [osx-arm64] separately)
    and the postcondition glob, because the two object formats spell a
    versioned library on opposite sides of the extension —
    [lib/libz.so.1*] against [lib/libz.1*.dylib]. *)
type build = {
  url : string;  (** the archive to download *)
  lib_glob : string;
      (** what must exist afterwards, relative to the tag dir — the
          preparation's own postcondition, e.g. "lib/libffi.so*" *)
}

(** One declared prebuilt: what to fetch, where it lands, and WHY this
    source/version was chosen (the rationale is carried, not folklore —
    a reader of the spec should not have to reconstruct it).

    ONE VERSION, PER-PLATFORM ARCHIVES. [version] is the world's claim
    and is shared: the whole point of the lib channel pair is that both
    machines test the SAME second version, so a per-platform version
    would silently make the two runs incomparable. The convention when
    declaring the pair is same version, same conda BUILD NUMBER, only the
    platform hash differing — all four current prebuilts satisfy it.

    [macos = None] states that no prebuilt is obtainable for this
    platform yet. That is a real answer (the sourcing rule can fail),
    and stating it beats a URL that 404s at prepare time: `prebuilt`
    reports it and the vendored cell is honestly absent rather than
    mysteriously broken. *)
type t = {
  project : string;
      (** the contrib family: [contrib/<project>-all/prebuilt/…] *)
  tag : string;  (** the dir under [prebuilt/], e.g. "libffi-3.7.0" *)
  version : string;  (** the dotted version the world declares *)
  linux : build;
  macos : build option;  (** [None] = none obtainable for macOS yet *)
  note : string;
      (** why THIS source and version (the sourcing rule's answer for
          this lib) — surfaced by `spec` / `spec-check` *)
}

(** The archive + postcondition for a platform, when one is declared. *)
let build_of (d : t) (distro : Canary_store.distro) : build option =
  match distro with
  | Canary_store.Wsl -> Some d.linux
  | Canary_store.MacOS_local -> d.macos

(** The postcondition glob, or [""] when this platform has no declared
    prebuilt — callers use it inside an [ls] that then finds nothing,
    which is the same answer as "not prepared". *)
let lib_glob_of (d : t) (distro : Canary_store.distro) : string =
  match build_of d distro with Some b -> b.lib_glob | None -> ""

(** The prepared location: [<contrib>/<project>-all/prebuilt/<tag>]. Same
    shape as the per-ref build (`build-<ref>`) and staging
    (`install-<ref>`) dirs, so one convention covers checkouts, builds,
    staging areas and prebuilts. *)
let path_of (d : t) (distro : Canary_store.distro) : string =
  Printf.sprintf "%s/%s-all/prebuilt/%s"
    (Canary_store.contrib_root distro)
    d.project d.tag

(** The lib directory a consumer points at (LD_LIBRARY_PATH, -L). *)
let libdir_of (d : t) (distro : Canary_store.distro) : string =
  path_of d distro ^ "/lib"

(** The preparation command — idempotent, and version-stamped so a
    changed declaration re-prepares (the landing lesson: a command must
    name the identity of what it produces, or its cache entry lies).

    Format handling: conda's modern [.conda] is a ZIP whose members are
    zstd-compressed tarballs; the older [.tar.bz2] is a plain tarball.
    Both are handled, so a declaration can name whichever the channel
    has.

    A platform with no declared prebuilt gets a command that FAILS with
    the reason, rather than one that half-runs: preparation is the whole
    contract here, so "there is no archive for this platform" must be
    said out loud at the point someone asks for it. *)
let prepare_cmd (d : t) (distro : Canary_store.distro) : string =
  match build_of d distro with
  | None ->
      Printf.sprintf
        "echo 'no prebuilt declared for this platform: %s %s' >&2; exit 1"
        d.project d.version
  | Some b ->
      let dir = path_of d distro in
      let stamp = Printf.sprintf "%s/.prepared-%s" dir d.version in
      let is_conda = String.is_suffix b.url ~suffix:".conda" in
      let unpack =
        if is_conda then
          "unzip -oq a.conda && tar --zstd -xf pkg-*.tar.zst && rm -f \
           a.conda pkg-*.tar.zst info-*.tar.zst metadata.json"
        else "tar -xf a.tar.bz2 && rm -f a.tar.bz2"
      in
      let archive = if is_conda then "a.conda" else "a.tar.bz2" in
      Printf.sprintf
        "test -f %s || { mkdir -p %s && cd %s && curl -sL %s -o %s && %s && \
         ls %s/%s >/dev/null 2>&1 && rm -f %s/.prepared-* && touch %s ; }"
        stamp dir dir b.url archive unpack dir b.lib_glob dir stamp

(** Has the prebuilt been prepared (the declared lib present)? A pure
    filesystem read — the spec display and the CLI both use it, so a
    missing preparation is VISIBLE rather than a late run failure. *)
let is_prepared (d : t) (distro : Canary_store.distro) : bool =
  let dir = path_of d distro in
  match Stdlib.Sys.file_exists dir with
  | false -> false
  | true -> (
      (* the stamp is the identity check; the glob is its postcondition *)
      let stamp = Printf.sprintf "%s/.prepared-%s" dir d.version in
      Stdlib.Sys.file_exists stamp
      &&
      match Stdlib.Sys.file_exists (dir ^ "/lib") with
      | false -> false
      | true -> not (Array.is_empty (Stdlib.Sys.readdir (dir ^ "/lib"))))

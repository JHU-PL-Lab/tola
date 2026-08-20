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

(** One declared prebuilt: what to fetch, where it lands, and WHY this
    source/version was chosen (the rationale is carried, not folklore —
    a reader of the spec should not have to reconstruct it). *)
type t = {
  project : string;
      (** the contrib family: [contrib/<project>-all/prebuilt/…] *)
  tag : string;  (** the dir under [prebuilt/], e.g. "libffi-3.7.0" *)
  version : string;  (** the dotted version the world declares *)
  url : string;  (** the archive to download *)
  lib_glob : string;
      (** what must exist afterwards, relative to the tag dir — the
          preparation's own postcondition, e.g. "lib/libffi.so*" *)
  note : string;
      (** why THIS source and version (the sourcing rule's answer for
          this lib) — surfaced by `spec` / `spec-check` *)
}

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
    has. *)
let prepare_cmd (d : t) (distro : Canary_store.distro) : string =
  let dir = path_of d distro in
  let stamp = Printf.sprintf "%s/.prepared-%s" dir d.version in
  let is_conda = String.is_suffix d.url ~suffix:".conda" in
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
    stamp dir dir d.url archive unpack dir d.lib_glob dir stamp

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

open Packaging

module String_named_pkg =
  Package.Make (Package.String_pname) (Versioning.Multi_part)

module String_pkg = String_named_pkg (Package.String_payload)

module String_pkgm =
  (* Manager.Make (Package.Legacy_string_pkg) *)
  Manager.Make (String_pkg)

module Lt_pkg = String_named_pkg (Langs.Payload.Lt_payload)
module Lt_pkgm = Manager.Make (Lt_pkg)
module Boat_pkg = String_named_pkg (Langs.Payload.Boat_payload)
module Boat_pkgm = Manager.Make (Boat_pkg)

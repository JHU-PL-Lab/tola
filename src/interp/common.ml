(* open Base *)
open Packaging

(* pkgm components *)
module String_named_pkg =
  Package.Make (Package.String_pname) (Versioning.Multi_part)

module String_pkg = String_named_pkg (Package.String_payload)
module String_pkgm = Manager.Make (String_pkg)

(* Lang lambda_text *)

module Lt_pkg = String_named_pkg (Langs.Payload.Lt_payload)
module Lt_pkgm = Manager.Make (Lt_pkg)
module Lt_P_Cmd = Pkgm_cmd.Make (Lt_pkgm)
module Lt_interp = Text_interp.Make_interp_via_pname (Lt_pkgm)

let lt_pm_config = Spec.mk_config "lt" "lt" "main.json"

(* Lang markdown *)
module Md_P_Cmd = Pkgm_cmd.Make (String_pkgm)
module Md_expand = Md_expand.Make (String_pkgm)

let md_pm_config = Spec.mk_config "markdown" "md" "main.json"

(* Lang boat *)

module Boat_pkg = String_named_pkg (Langs.Payload.Boat_payload)
module Boat_pkgm = Manager.Make (Boat_pkg)

module Boat_interp =
  Boat_interp.Make_interp (Boat_pkgm) (Manager.Default_options)

module Boat_P_Cmd = Pkgm_cmd.Make (Boat_pkgm)

let boat_pm_config = Spec.mk_config "boat" "boat" "main.json"

(* Lang sh *)
module Sh_P_cmd = Pkgm_cmd.Make (String_pkgm)
module Sh_interp = Bash_interp.Make (String_pkgm)

let sh_pm_config = Spec.mk_config "bash" "sh" "main.json"

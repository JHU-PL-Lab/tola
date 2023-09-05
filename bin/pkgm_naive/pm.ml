open Packaging

module Local_demo_config : Packaging.Naive.NAIVE_CONFIG = struct
  let pkgm_root = Filename.concat (Sys.getcwd ()) "demo"
  let pkgm_id = "text"
end

module Pkgm =
  Naive_manager.Make (Package.String_pkg) (Shared.Pkg_table) (Local_demo_config)

module PM_cmd = Cmd.Make (Pkgm)

let () = PM_cmd.main ()

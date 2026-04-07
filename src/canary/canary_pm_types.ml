(* Shared types for PM modules. Separate file to avoid dependency
   cycles between canary_store (which dispatches to PM modules)
   and PM modules (which declare their properties). *)

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

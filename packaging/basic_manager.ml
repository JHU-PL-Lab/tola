(* A basic pkgm is with a local store and a remote store.
   The store is a toml-file based package as `<pid>.toml`.
*)

module type STORE = sig
  type t
  type pid
  type pkg
end

module type LOCAL_STORE = sig
  type t
  type pid
  type pkg
  type store
end

module type REMOTE_STORE = sig
  type t
  type pid
  type pkg
  type store
end

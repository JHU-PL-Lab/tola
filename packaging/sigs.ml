module type LOOKUPABLE = sig
  type pid
  type pkg

  val lookup : pid -> pkg
end

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

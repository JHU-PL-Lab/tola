module type PACKAGE = sig
  type pid
  type pkg
end

module String_pkg : PACKAGE with type pid = string and type pkg = string =
struct
  type pid = string
  type pkg = string
end

module Resolve_strategy = struct
  (* How matching is determined *)
  type check_kind =
    | Via_name (* Match based on name or versioned name *)
    | Via_value (* Match based on value identity: hash, ABI *)
    | Via_both (* Require both name and value to align *)
    | Via_ctx (* Use external/global context to resolve *)

  (* Resolution stage represents how far the resolution progresses *)
  type resolve_stage = Bound_to_name | Resolved_to_value

  (* Kind of name used in binding *)
  type name_kind = Id | With_path | With_version

  (* A unified structure to represent a single-step resolution *)
  type t = {
    stage : resolve_stage; (* what this step resolves to *)
    check_kind : check_kind; (* how to match during resolution *)
    name_kind : name_kind; (* structure of the name used *)
  }

  (* A full multi-step resolution process *)
  type trace = t list (* sequence of resolution steps *)
end

(* What phase performs binding or resolution? *)
type resolve_phase =
  | Configure_time
  | Build_time
  | Install_time
  | Compile_time
  | Link_time
  | Load_time
  | Run_time

module Resolve_action_spec = struct
  type fallback_policy = Fail | Try_alternatives of string list | Use_default
  type mutability = Fixed | Rebindable
end

(* One step of a system that binds/resolves a symbol *)
type resolve_action = { strategy : Resolve_strategy.t; phase : resolve_phase }

(* Example actions based on common linking models *)
module Resolve_example = struct
  open Resolve_strategy

  let static_linking =
    {
      strategy =
        { stage = Resolved_to_value; check_kind = Via_value; name_kind = Id };
      phase = Build_time;
    }

  let ocaml_native_cmx =
    {
      strategy =
        { stage = Resolved_to_value; check_kind = Via_value; name_kind = Id };
      phase = Compile_time;
    }

  let rust_crate_hash =
    {
      strategy =
        { stage = Resolved_to_value; check_kind = Via_value; name_kind = Id };
      phase = Compile_time;
    }

  let c_static_link =
    {
      strategy =
        { stage = Resolved_to_value; check_kind = Via_value; name_kind = Id };
      phase = Build_time;
    }

  let shared_library_link =
    {
      strategy =
        { stage = Bound_to_name; check_kind = Via_name; name_kind = With_path };
      phase = Link_time;
    }

  let linux_loader =
    {
      strategy =
        { stage = Bound_to_name; check_kind = Via_name; name_kind = With_path };
      phase = Load_time;
    }

  let plugin_load =
    {
      strategy =
        {
          stage = Bound_to_name;
          check_kind = Via_ctx;
          name_kind = With_version;
        };
      phase = Run_time;
    }

  let dynamic_resolve_strict =
    {
      strategy =
        {
          stage = Bound_to_name;
          check_kind = Via_both;
          name_kind = With_version;
        };
      phase = Run_time;
    }

  let python_importlib =
    {
      strategy =
        { stage = Bound_to_name; check_kind = Via_ctx; name_kind = With_path };
      phase = Run_time;
    }

  let java_classloader_strict =
    {
      strategy =
        { stage = Bound_to_name; check_kind = Via_name; name_kind = With_path };
      phase = Run_time;
    }
end

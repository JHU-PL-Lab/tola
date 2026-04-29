open Base
open Lang_yelu_type

module Make_state_op (T : LANG_TYPES) = struct
  type yelu_state_stmt =
    (* plain variables *)
    | Ystate_set of { cvar : T.var; values : T.expr list; parent_scope : bool }
    (* cache *)
    | Ystate_option of { cvar : T.var; msg : string; value : T.expr }
    | Ystate_set_cache of {
        cvar : T.var;
        values : T.expr list;
        cache_type : Lang_cmake.cache_type;
        docstring : string;
        force : bool;
      }
    | Ystate_unset_cache of { cvar : T.var }
    (* env *)
    | Ystate_set_env of { var : string; value : T.expr }
    | Ystate_unset_env of { var : string }
    (* property — dynamic property types not modelled at S0; see yelu_typed_design.md *)
    | Ystate_get_property of {
        var : T.var;
        target : T.expr;
        property : string;
        set : bool;
      }
    | Ystate_get_directory_property of { var : T.var; property : string }
    | Ystate_set_directory_property of {
        property : string;
        append : bool;
        values : T.expr list;
      }
    | Ystate_set_tests_properties of {
        tests : T.expr list;
        properties : (string * T.expr) list;
      }
    | Ystate_set_target_properties of {
        target : T.expr;
        properties : (string * T.expr) list;
      }
    | Ystate_set_property of {
        targets : T.expr list;
        append : bool;
        properties : (string * T.expr) list;
      }
    | Ystate_set_source_property of {
        file : T.expr;
        property : string;
        values : T.expr list;
      }
    | Ystate_set_global_property of { properties : (string * T.expr) list }
    | Ystate_get_global_property of { var : T.var; property : string }
    | Ystate_get_target_property of {
        var : T.var;
        target : string;
        property : string;
      }
    | Ystate_define_property of {
        mode : Lang_cmake.define_property_mode;
        property_name : string;
        inherited : bool;
        brief_docs : string list;
        full_docs : string list;
        initialize_from : string option;
      }
end

module Make_state_check (T : LANG_TYPES) = struct
  include Make_state_op (T)

  (* cache_type maps directly to yelu_type for set_cache output.
     Property ops return Ty_any — property value types are stringly-keyed and dynamic;
     deeper typing requires a property schema (see yelu_typed_design.md §Make_state_op).
     Env vars are not tracked in the type env (process-level, no yelu binding). *)
  let cache_type_to_yelu_type = function
    | Lang_cmake.Ct_bool -> Ty_bool
    | Lang_cmake.Ct_path | Lang_cmake.Ct_filepath -> Ty_path
    | Lang_cmake.Ct_string | Lang_cmake.Ct_internal -> Ty_string

  let check ~(type_of : T.expr -> yelu_type)
      : yelu_state_stmt -> type_error list * (T.var * yelu_type) list =
    let strs es ctx = List.concat_map es ~f:(fun e -> check_compat ~context:ctx Ty_string (type_of e)) in
    function
    | Ystate_set { cvar; values; _ } ->
      strs values "state_set", [(cvar, Ty_string)]
    | Ystate_option { cvar; value; _ } ->
      check_compat ~context:"option" Ty_bool (type_of value), [(cvar, Ty_bool)]
    | Ystate_set_cache { cvar; values; cache_type; _ } ->
      strs values "set_cache", [(cvar, cache_type_to_yelu_type cache_type)]
    | _ -> [], []
end

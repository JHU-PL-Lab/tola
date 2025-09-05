open Base

module Lt_payload = struct
  type payload = Lang_text.With_string_pid.exp

  let exp_of_yojson json =
    json |> Yojson.Safe.to_basic |> Yojson.Basic.Util.to_string
    |> Lang_text.Parse.parse

  let payload_of_yojson = exp_of_yojson
  let yojson_of_exp exp = `String (Fmt.to_to_string Lang_text.Parse.Pp.exp exp)
  let yojson_of_payload = yojson_of_exp
end

module Boat_payload = struct
  type payload = Lang_boat.exp

  let exp_of_yojson json =
    json |> Yojson.Safe.to_basic |> Yojson.Basic.Util.to_string
    |> Boat_parse.of_string_no_eol_opt |> Option.value_exn

  let payload_of_yojson = exp_of_yojson
  let yojson_of_exp exp = `String (Fmt.to_to_string Lang_boat.pp_exp exp)
  let yojson_of_payload = yojson_of_exp
end

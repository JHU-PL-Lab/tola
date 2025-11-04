(* open Base

module Macho_otool = struct

let i k = int_of_hex_or_dec (Option.value (get k) ~default:"0") in
Data_in_code { dataoff=i "dataoff"; datasize=i "datasize" }
| Some cmd when String.(cmd = "LC_CODE_SIGNATURE") ->
let i k = int_of_hex_or_dec (Option.value (get k) ~default:"0") in
Code_signature { dataoff=i "dataoff"; datasize=i "datasize" }
| Some cmd when String.(cmd = "LC_DYLD_INFO_ONLY") ->
let i k = int_of_hex_or_dec (Option.value (get k) ~default:"0") in
Dyld_info_only {
rebase_off=i "rebase_off"; rebase_size=i "rebase_size";
bind_off=i "bind_off"; bind_size=i "bind_size";
weak_bind_off=i "weak_bind_off"; weak_bind_size=i "weak_bind_size";
lazy_bind_off=i "lazy_bind_off"; lazy_bind_size=i "lazy_bind_size";
export_off=i "export_off"; export_size=i "export_size";
}
| Some cmd when String.(cmd = "LC_DYLD_EXPORTS_TRIE") ->
let i k = int_of_hex_or_dec (Option.value (get k) ~default:"0") in
Dyld_exports_trie { dataoff=i "dataoff"; datasize=i "datasize" }
| Some cmd when String.(cmd = "LC_DYLD_CHAINED_FIXUPS") ->
let i k = int_of_hex_or_dec (Option.value (get k) ~default:"0") in
Dyld_chained_fixups { dataoff=i "dataoff"; datasize=i "datasize" }
| Some cmd -> Unknown { cmd; fields }
| None -> Unknown { cmd="<missing>"; fields }


(* Parse a single load-command block lines (without the leading "Load command N") *)
let parse_block (lines:string list) : load_command =
let rec loop (blk:raw_block) (ls:string list) (cur_section:(string * (string * string) list) option)
: raw_block =
match ls with
| [] ->
let blk = (match cur_section with None -> blk | Some sec -> { blk with sections = blk.sections @ [sec] }) in
blk
| l::rest ->
let l = strip l in
if is_blank l then loop blk rest cur_section else
if String.is_prefix l ~prefix:"cmd " || String.is_prefix l ~prefix:"cmd " then
(* e.g., "cmd LC_SEGMENT_64" or "cmd LC_LOAD_DYLIB" *)
let cmd = take_after_prefix ~prefix:"cmd" l in
{ blk with cmd = Some (strip cmd) } |> fun blk' -> loop blk' rest cur_section
else if String.is_prefix l ~prefix:"Section" then
(* finish previous section if any, start a new one *)
let blk = (match cur_section with None -> blk | Some sec -> { blk with sections = blk.sections @ [sec] }) in
loop blk rest (Some ("Section", []))
else (
match String.lsplit2 ~on:' ' l with
| Some (k, v) when String.(k = "Section") -> loop blk rest (Some ("Section", []))
| Some (k, v) ->
let kv = (strip k, strip v) in
begin match cur_section with
| None -> loop { blk with fields = blk.fields @ [kv] } rest None
| Some (tag, kvs) -> loop blk rest (Some (tag, kvs @ [kv]))
end
| None -> loop blk rest cur_section)
in
let blk = loop empty_block lines None in
build_load_command blk


(* Split the whole text by load-command blocks *)
let parse (s:string) : macho =
let lines = String.split_lines s in
let rec split acc cur_file cur_block blocks = function
| [] ->
let cmds = List.rev (List.map blocks ~f:parse_block) in
{ file = Option.value cur_file ~default:""; load_commands = cmds }
| l::rest ->
let l' = strip l in
if String.is_suffix l' ~suffix:":" && not (String.is_prefix l' ~prefix:"Load command") then
(* header line: "/path/file:" *)
split acc (Some (String.chop_suffix_exn l' ~suffix:":")) cur_block [] rest
else if String.is_prefix l' ~prefix:"Load command " then
(* close previous block *)
let blocks = (match cur_block with [] -> blocks | _ -> blocks @ [List.rev cur_block]) in
split acc cur_file [ ] blocks rest
else
split acc cur_file (l'::cur_block) blocks rest
in
split [] None [] [] lines


let parse_many (s:string) : macho list =
(* Split by lines ending with ':' that are not 'Load command N' *)
let groups =
s |> String.split_lines
|> List.groupi ~break:(fun _ a b ->
let a = strip a and b = strip b in
String.is_suffix a ~suffix:":" && not (String.is_prefix a ~prefix:"Load command") )
in
let rec of_group = function
| [] -> []
| g :: rest ->
let text = String.concat ~sep:"
" g in
let m = parse text in
m :: of_group rest
in
of_group groups
end *)

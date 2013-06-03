open Core.Std
open Textutils.Std

type input = {
  file : string;
  lines : string list;
} with sexp

type change = {
  line_number: int;
  old_line: string;
  new_line: string;
} with sexp

type change_set = {
  path : string;
  changes : change list;
} with sexp

type input_type =
  | Grouped
  | Ungrouped with sexp

module E = struct
  exception Does_not_exist of string * string with sexp
  exception Invalid_change of string with sexp

  let wrong_exception function_name =
    raise (Invalid_argument (function_name ^ ", wrong exception"))

  let dne_to_string = function
    | Does_not_exist (dir, path) ->
      sprintf "Could not find %s in %s. Maybe -w is set wrong?" path dir
    | _ -> wrong_exception "dne_to_string"

  let invalid_change line = raise (Invalid_change line)
  let invalid_change_to_string = function
    | Invalid_change line -> sprintf "Bad line: '%s'" line
    | _ -> wrong_exception "invalid_change_to_string"
end

let detect_input input = Ungrouped (* TODO *)

let input_grouped input = failwith "TODO"

let group_remove l ~f = 
  match List.group l ~break:(fun _ x -> f x) with
  | x::xs -> x::(List.map xs ~f:List.tl_exn)
  | [] -> []

let parse_change line = 
  match String.split line ~on:':' with
  | line::rest ->
    object
      method line = Int.of_string line
      method new_line = String.concat rest
    end
  | [] -> E.invalid_change line

let input_ungrouped input = 
  let inp = String.Table.create () in
  input |> List.iter ~f:(fun line -> 
      let (fname, data) = String.lsplit2_exn line ~on:':' in
      inp |> Hashtbl.add_multi ~key:fname ~data); 
  inp |> Hashtbl.to_alist |> List.map ~f:(fun (file, lines) ->
      {file; lines})

let write_change_set {path; changes} =
  let arr = path |> In_channel.read_lines |> Array.of_list in
  changes |> List.iter ~f:(fun {line_number;old_line;new_line} ->
      let i = pred line_number in
      if arr.(i) <> old_line then
        failwith (sprintf "Read mismatch %s <> %s" arr.(i) old_line)
      else 
        arr.(i) <- new_line);
  Out_channel.write_lines path (Array.to_list arr)

let get_lines ~path lines = 
  let file = path |> In_channel.read_lines |> Array.of_list in
  lines |> List.map ~f:(fun i -> file.(i-1))

let change_set_of_input {file; lines} = 
  let no_old_lines = lines |> List.map ~f:(fun cg ->
      let cg = parse_change cg in
      { line_number=cg#line ;
        new_line=cg#new_line ;
        old_line="";
      }) in
  let old_lines = no_old_lines 
                  |> List.map ~f:(fun {line_number;_} -> line_number)
                  |> get_lines ~path:file in
  { changes=(List.map2_exn no_old_lines old_lines
               ~f:(fun cg old_line -> { cg with old_line }));
    path=file }

let parse_changes ~dir input = 
  let inputs = 
    match detect_input input with
    | Grouped -> input_grouped input
    | Ungrouped -> input_ungrouped input
  in
  inputs |> List.map ~f:(fun input ->
      let path = Filename.concat dir input.file in
      match Sys.file_exists path with
      | `No -> raise (E.Does_not_exist (dir, input.file))
      | `Yes | `Unknown -> change_set_of_input {input with file=path}
    )


module Printers = struct
  let no_color = object
    method no_changes s = printf "No changes to %s\n" s
    method fname s = printf "%s\n" s
    method diff ~old_line ~new_line = 
      printf "- %s\n" old_line;
      printf "+ %s\n" new_line
  end
  let color = object
    method no_changes = no_color#no_changes
    method fname f = Console.Ansi.printf [`Green] "%s\n" f
    method diff ~old_line ~new_line = 
      Console.Ansi.printf [`Red] "- ";
      print_endline old_line;
      Console.Ansi.printf [`Yellow] "+ ";
      print_endline new_line
  end
  let _c = color 
  let get_printer ~color = if color then _c else no_color
end


let preview_changes change_sets ~color = (* TODO color not supported *)
  let printer = Printers.get_printer ~color in
  change_sets |> List.iter ~f:(fun {path; changes} ->
      if List.is_empty changes then printer#no_changes path
      else begin
        printer#fname path;
        changes |> List.iter 
          ~f:(fun {old_line; new_line; _} -> printer#diff ~old_line ~new_line)
      end)

let write_changes change_sets = change_sets |> List.iter ~f:write_change_set


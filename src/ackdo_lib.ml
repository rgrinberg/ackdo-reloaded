open Core.Std
open Textutils.Std
exception Unimplemented of string with sexp

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

  let to_string = function
    | Does_not_exist (dir, path) ->
      Some (sprintf "Could not find %s in %s. Maybe -w is set wrong?" path dir)
    | Invalid_change line -> Some (sprintf "Bad line: '%s'" line)
    | _exn -> None

  let invalid_change line = raise (Invalid_change line)
  let does_not_exist ~dir ~file = raise (Does_not_exist (dir, file))

  let handle_exn _exn = 
    match to_string _exn with
    | None -> failwiths "Wrong exn" _exn sexp_of_exn
    | Some s -> printf "Error: %s\n" s
end

(* Grouped inuput is not used very often so it's not currently supported *)

let detect_input _ = raise (Unimplemented "grouped input not supported")

let input_grouped _ = raise (Unimplemented "grouped input not supported")

let group_remove l ~f = 
  match List.group l ~break:(fun _ x -> f x) with
  | x::xs -> x::(List.map xs ~f:List.tl_exn)
  | [] -> []

let parse_change line = 
  match String.split line ~on:':' with
  | line::rest ->
    object
      method line = Int.of_string line
      method new_line = String.concat ~sep:":" rest
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
      | `No -> E.does_not_exist ~dir ~file:input.file
      | `Yes | `Unknown -> change_set_of_input {input with file=path}
    )

module Diff = struct
  let longest_common_subsequence x y =
    let (n, m) = String.(length x, length y) in
    let tbl = Array.init (n+1) (fun _ -> Array.create ~len:(m+1) 0) in
    for i = 0 to n do tbl.(i).(0) <- 0 done;
    for i = 0 to m do tbl.(0).(i) <- 0 done;
    for i = 1 to n do
      for j = 1 to m do
        if x.[i-1] = y.[j-1] then
          tbl.(i).(j) <- tbl.(i-1).(j-1) + 1
        else
          tbl.(i).(j) <- max tbl.(i-1).(j) tbl.(i).(j-1)
      done
    done;
    let rec reco acc i j = 
      if i = 0 || j = 0 then
        acc
      else if x.[i-1] = y.[j-1] then
        reco ((x.[i-1])::acc) (i-1) (j-1)
      else if tbl.(i-1).(j) > tbl.(i).(j-1) then
        reco acc (i-1) j
      else
        reco acc i (j-1)
    in String.of_char_list (reco [] n m)

  let split_lcs str lcs = 
    let (len, lcs_len) = String.(length str, length lcs) in
    let marked = Array.create ~len (`no_lcs '_') in
    let lcs_pos = ref 0 in
    for i = 0 to len - 1 do
      if (!lcs_pos < lcs_len) && (str.[i] = lcs.[!lcs_pos]) then
        begin
          marked.(i) <- `lcs (str.[i]);
          incr lcs_pos
        end
      else marked.(i) <- `no_lcs (str.[i])
    done;
    assert ((String.length lcs) = !lcs_pos);
    let untag = function | `lcs x | `no_lcs x -> x in
    let extract word = word |> List.map ~f:untag |> String.of_char_list in
    marked |> Array.to_list
    |> List.group ~break:(fun x y -> match x, y with
        | `lcs _ , `lcs _ | `no_lcs _ , `no_lcs _ -> false
        | _, _ -> true)
    |> List.map ~f:(fun word ->
        match List.hd_exn word with
        | `lcs _ -> `lcs (extract word)
        | `no_lcs _ -> `no_lcs (extract word))

  let diff s1 s2 = 
    let lcs = longest_common_subsequence s1 s2 in
    (split_lcs s1 lcs, split_lcs s2 lcs)
end

module Printers = struct
  let no_color = object
    method no_changes s = printf "No changes to %s\n" s
    method fname s = printf "%s\n" s
    method diff ~old_line ~new_line = 
      printf "- %s\n" old_line;
      printf "+ %s\n" new_line
  end
  let color = object(self)
    method no_changes = no_color#no_changes
    method fname f = Console.Ansi.printf [`Green] "%s\n" f

    method private print_line attrs diffed_line = 
      diffed_line |> List.iter ~f:(function
          | `lcs s -> print_string s
          | `no_lcs s -> Console.Ansi.printf attrs "%s" s)

    method diff ~old_line ~new_line = 
      let no_lcs_color = [`Red] in
      let (d1, d2) = Diff.diff old_line new_line in
      print_string "- ";
      self#print_line no_lcs_color d1;
      print_string "\n+ ";
      self#print_line no_lcs_color d2;
      print_newline ()

  end
  let _c = color 
  let get_printer ~color = if color then _c else no_color
end

let preview_changes change_sets ~color =
  let printer = Printers.get_printer ~color in
  change_sets |> List.iter ~f:(fun {path; changes} ->
      if List.is_empty changes then printer#no_changes path
      else begin
        printer#fname path;
        changes |> List.iter 
          ~f:(fun {old_line; new_line; _} -> printer#diff ~old_line ~new_line)
      end)

let write_changes change_sets = change_sets |> List.iter ~f:write_change_set


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

module E : sig
  val handle_exn : exn -> unit
end

val get_lines : path : string -> int list -> string list

val change_set_of_input : input -> change_set

val detect_input : string list -> input_type

val input_grouped : string list -> input list

val input_ungrouped : string list -> input list

val parse_changes : dir:string -> string list -> change_set list

val preview_changes : change_set list -> color:bool -> unit

val write_change_set : change_set -> unit

val write_changes : change_set list -> unit

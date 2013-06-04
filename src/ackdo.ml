open Core.Std

let command =
  Command.basic
    ~summary:"Ackdo - ack + sed companion"
    Command.Spec.(
      empty
      +> flag "-d" (no_arg)
          ~doc:" Write changes. Mnemonic: d => do"
      +> flag "-w" (optional_with_default (Unix.getcwd ()) string)
          ~doc:"directory Set the directory to lookup the files in the change
          set The default is cwd"
      +> flag "-c" (no_arg)
          ~doc:" Turn off color output"
    ) (fun commit dir color () -> 
        let open Ackdo_lib in
        try begin
          let input = In_channel.(input_lines stdin) in
          let change_sets = Ackdo_lib.parse_changes ~dir input in
          if commit then Ackdo_lib.write_changes change_sets
          else Ackdo_lib.preview_changes change_sets ~color:(not color)
        end
        with _exn -> E.handle_exn _exn
      )

let () = Exn.handle_uncaught ~exit:true (fun () -> Command.run command)

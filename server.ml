open Core.Std
open Async.Std
open Telegram_j

type command =
  | Dolly

let command_of_string str =
  let str =
    if String.contains str '@'
    then fst (String.lsplit2_exn str ~on:'@')
    else str
  in match str with
  | "/dolly" -> Dolly
  | _ -> failwith "Invalid command"

let handle_dolly chat_id args =
  let photo =
    match args with
    | _ -> "AgADBQADyqcxG80qggkuBj1QNJ2NXjdTvjIABG35SEH4FlJfYY0BAAEC"
  in let photo_r = { response_method = `SendPhoto;
                     chat_id = chat_id;
                     photo = photo;
                     caption = None; }
  in let response = `String (string_of_photo_reply photo_r)
  in let headers = Cohttp.Header.of_list [("Content-Type",
                                           "application/json")]
  in Cohttp_async.Server.respond ~headers:headers ~body:response `OK

let response_from_update { update_id = _; message = maybe; } =
  match maybe with
  | Some msg ->
    begin
      match msg with
      | { text = Some text; _ } ->
        let tokens = Str.bounded_split (Str.regexp "[ ]+") text 2
        in let command = command_of_string (List.hd_exn tokens)
        in let args = List.nth tokens 1
        in begin
          match command with
          | Dolly -> handle_dolly msg.chat.chat_id args
        end
      | _ ->
        Log.Global.error "Unknown message: %s" (string_of_message msg);
        Cohttp_async.Server.respond `OK
    end
  | None -> failwith "No message in update"

let run ~port =
  Cohttp_async.Server.create
    ~on_handler_error:`Raise
    (Tcp.on_port port)
    (fun ~body _ req ->
       match (Cohttp.Request.meth req) with
       | `POST ->
         Cohttp_async.Body.to_string body
         >>= (fun body ->
             Log.Global.info "POST: %s" body;
             response_from_update (update_of_string body))
       | _ -> Cohttp_async.Server.respond `Method_not_allowed
    )
  >>= fun _ -> Deferred.never ()

let () =
  Command.async_basic
    ~summary:"Start a telegram bot server"
    Command.Spec.(
      empty
      +> flag "-port" (optional_with_default 8080 int)
        ~doc: " Port to listen on (default 8080)"
    )
    (fun port () -> run ~port)
  |> Command.run


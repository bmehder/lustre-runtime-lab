import counter
import gleam/erlang/process.{type Selector, type Subject}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{type Option, Some}
import lustre
import lustre/server_component
import mist.{type Connection, type ResponseData}

// Subscribe each connection to the existing runtime, rather than starting one.
pub fn connect(
  request: Request(Connection),
  runtime: lustre.Runtime(counter.Msg),
) -> Response(ResponseData) {
  mist.websocket(
    request:,
    on_init: fn(_) { init_socket(runtime) },
    handler: handle_socket,
    on_close: close_socket,
  )
}

type Socket {
  Socket(runtime: lustre.Runtime(counter.Msg), client: Subject(ClientMessage))
}

type ClientMessage =
  server_component.ClientMessage(counter.Msg)

fn init_socket(
  runtime: lustre.Runtime(counter.Msg),
) -> #(Socket, Option(Selector(ClientMessage))) {
  let client: Subject(ClientMessage) = process.new_subject()
  let selector = process.new_selector() |> process.select(client)
  server_component.register_subject(client) |> lustre.send(to: runtime)
  #(Socket(runtime:, client:), Some(selector))
}

fn handle_socket(
  state: Socket,
  message: mist.WebsocketMessage(ClientMessage),
  connection: mist.WebsocketConnection,
) -> mist.Next(Socket, ClientMessage) {
  case message {
    mist.Text(text) -> {
      case json.parse(text, server_component.runtime_message_decoder()) {
        Ok(message) -> lustre.send(state.runtime, message)
        Error(_) -> Nil
      }
      mist.continue(state)
    }
    mist.Custom(message) -> {
      let text =
        message |> server_component.client_message_to_json |> json.to_string
      case mist.send_text_frame(connection, text) {
        Ok(_) -> mist.continue(state)
        Error(_) -> mist.stop()
      }
    }
    mist.Binary(_) -> mist.continue(state)
    mist.Closed | mist.Shutdown -> mist.stop()
  }
}

fn close_socket(state: Socket) -> Nil {
  // Detach this subscriber; the shared model keeps running.
  server_component.deregister_subject(state.client)
  |> lustre.send(to: state.runtime)
}

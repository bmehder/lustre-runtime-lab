import counter
import gleam/erlang/process.{type Selector, type Subject}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{type Option, Some}
import lustre
import lustre/server_component
import mist.{type Connection, type ResponseData}

// Start a fresh counter for each WebSocket connection.
pub fn connect(request: Request(Connection)) -> Response(ResponseData) {
  mist.websocket(
    request:,
    on_init: init_socket,
    handler: handle_socket,
    on_close: close_socket,
  )
}

type Socket {
  Socket(runtime: lustre.Runtime(counter.Msg))
}

type ClientMessage =
  server_component.ClientMessage(counter.Msg)

fn init_socket(_) -> #(Socket, Option(Selector(ClientMessage))) {
  // This step creates a separate counter per connection, not shared state.
  let assert Ok(runtime) = lustre.start_server_component(counter.counter(), Nil)
  let client: Subject(ClientMessage) = process.new_subject()
  let selector = process.new_selector() |> process.select(client)
  server_component.register_subject(client) |> lustre.send(to: runtime)
  #(Socket(runtime:), Some(selector))
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
  lustre.shutdown() |> lustre.send(to: state.runtime)
}

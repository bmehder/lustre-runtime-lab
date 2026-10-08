import counter
import gleam/bytes_tree
import gleam/erlang/application
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/option.{None}
import gleam/string
import lustre
import mist.{type Connection, type ResponseData}
import per_connection
import shared_counter
import ssr

pub fn main() -> Nil {
  let assert Ok(shared) = lustre.start_server_component(counter.counter(), Nil)
  let assert Ok(_) =
    mist.new(fn(request) { handle_request(request, shared) })
    |> mist.bind("127.0.0.1")
    |> mist.port(1234)
    |> mist.start
  process.sleep_forever()
}

fn handle_request(
  request: Request(Connection),
  shared: lustre.Runtime(counter.Msg),
) -> Response(ResponseData) {
  case request.path_segments(request) {
    [] | ["index.html"] -> serve_file("../dist/index.html", "text/html")
    ["lustre_runtime_lab.js"] ->
      serve_file("../dist/lustre_runtime_lab.js", "text/javascript")
    ["lustre_runtime_lab.css"] ->
      serve_file("../dist/lustre_runtime_lab.css", "text/css")
    ["runtime.mjs"] -> {
      let assert Ok(priv) = application.priv_directory("lustre")
      serve_file(
        priv <> "/static/lustre-server-component.mjs",
        "text/javascript",
      )
    }
    ["ssr"] ->
      response.new(200)
      |> response.set_header("content-type", "text/html; charset=utf-8")
      |> response.set_body(
        mist.Bytes(bytes_tree.from_string(ssr.render(False))),
      )
    ["ssr-interactive"] ->
      response.new(200)
      |> response.set_header("content-type", "text/html; charset=utf-8")
      |> response.set_body(mist.Bytes(bytes_tree.from_string(ssr.render(True))))
    ["shared-ws"] -> shared_counter.connect(request, shared)
    ["ws"] -> per_connection.connect(request)
    [asset] if asset != ".." -> {
      case string.ends_with(asset, ".js") {
        True -> serve_file("../dist/" <> asset, "text/javascript")
        False ->
          response.new(404) |> response.set_body(mist.Bytes(bytes_tree.new()))
      }
    }
    _ -> response.new(404) |> response.set_body(mist.Bytes(bytes_tree.new()))
  }
}

fn serve_file(path: String, content_type: String) -> Response(ResponseData) {
  case mist.send_file(path, offset: 0, limit: None) {
    Ok(file) ->
      response.new(200)
      |> response.set_header("content-type", content_type)
      |> response.set_body(file)
    Error(_) ->
      response.new(404) |> response.set_body(mist.Bytes(bytes_tree.new()))
  }
}

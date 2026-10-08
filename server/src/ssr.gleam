import counter
import lustre/element

/// Render HTML for this request without starting a counter runtime.
pub fn render(interactive: Bool) -> String {
  let script = case interactive {
    True -> "<script type=\"module\" src=\"/ssr_client.js\"></script>"
    False -> ""
  }
  let description = case interactive {
    True ->
      "The server sends view(0). The browser then starts its own counter runtime against this HTML."
    False ->
      "The server renders view(0) for each request. The buttons have no running update loop."
  }
  let counter_html = element.to_string(counter.view(0))

  "<!doctype html>
<html lang=\"en\">
  <head>
    <meta charset=\"utf-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
    " <> script <> "
    <title>Lustre Runtime Lab — SSR</title>
    <link rel=\"stylesheet\" href=\"/lustre_runtime_lab.css\">
  </head>
  <body class=\"min-h-screen bg-slate-50 p-8 text-slate-900\">
    <main class=\"mx-auto max-w-xl\">
      <a href=\"/\">Back to the runtime comparison</a>
      <h1 class=\"mt-8 text-3xl font-semibold\">Server-rendered HTML</h1>
      <p class=\"mt-2 mb-8 text-slate-500\">" <> description <> "</p>
      <div id=\"ssr-counter\">" <> counter_html <> "</div>
    </main>
  </body>
</html>"
}

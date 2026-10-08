# Lustre Runtime Lab

A small counter lab comparing Lustre constructors, browser custom elements,
server components, and SSR with browser startup. Each example stays deliberately
simple so the runtime boundaries are easy to inspect. This checkpoint uses
Lustre 5.7.1 and Lustre development tools 2.4.0.

## Build and run

Run these commands from the **project root**, not `server/`:

```sh
gleam run -m lustre/dev build lustre_runtime_lab ssr_client
cd server
gleam run
```

One BEAM HTTP server listens on port 1234. Stop it with Ctrl+C.

| URL | What to inspect |
| --- | --- |
| [Comparison page](http://localhost:1234/) | Browser constructors, two Web Components, per-connection and shared server counters |
| [SSR only](http://localhost:1234/ssr) | Counter HTML in the HTTP response; buttons have no runtime |
| [SSR with browser startup](http://localhost:1234/ssr-interactive) | The same initial HTML, then an interactive browser counter |

After browser code, HTML, or CSS edits, rebuild from the root and refresh.
After server Gleam edits, restart `gleam run` from `server/`. There is no automatic
reload in this setup. The root package targets JavaScript; `server/` targets
Erlang. They share one website and port.

## Compare the runtime models

| Example | Where state lives | Where update and view execute | What crosses the network |
| --- | --- | --- | --- |
| `element` | No user-defined counter model | Static view constructed in the browser | Initial HTML, JS, and CSS assets |
| `simple` | Independent browser runtime | Browser; update returns a model | Assets; no counter messages |
| `application` | Independent browser runtime | Browser; update also returns effects | Assets; no counter messages |
| `component`, mounted with start | Independent browser runtime | Browser | Assets; no counter messages |
| Web Component | One browser runtime per custom element | Browser, rendering inside shadow DOM | Assets; no counter messages |
| Per-connection server component | One BEAM runtime per WebSocket | BEAM | Browser events to server; JSON DOM patches to browser |
| Shared server component | One BEAM runtime for all subscribers | BEAM | Events to server; patches to connected subscribers |
| SSR only | No retained counter model | BEAM calls view for each HTTP request | HTML and CSS |
| SSR with browser startup | Fresh browser model after startup | Initial view on BEAM; subsequent updates and views in browser | HTML, CSS, JS; no counter messages |

## Browser constructors

| File | Constructor | Behavior |
| --- | --- | --- |
| `src/examples/element.gleam` | `lustre.element(view())` | Static zero and disabled buttons |
| `src/examples/simple.gleam` | `lustre.simple(init, update, view)` | Int model and pure update |
| `src/examples/application.gleam` | `lustre.application(init, update, view)` | Logs the new count through an effect |
| `src/examples/component.gleam` | `lustre.component(init, update, view, [])` | Same logging effect, with component configuration available |

The interactive modules deliberately keep their own Model, Msg, init, update,
and view for comparison. Each exposes counter() to construct a definition and
main() to start it in a DOM container. A definition does not start a runtime.

Simple hides empty effects internally. Application makes effects explicit:
init and update return `#(Model, Effect(Msg))`. Our update returns an
`effect.from` callback; Lustre executes it to log in the browser console.
The unused dispatch parameter is how a more involved effect could send a message
back to the runtime.

An application also has its own update loop and can be mounted multiple times.
That alone does not distinguish it from a component. The empty component options
add no behavior here; the next examples demonstrate different ways to run a
component definition.

Element has no user-defined Model, Msg, init, or update. Internally its App uses
Nil state and a trivial update. It is still mounted in the browser with start;
this example is separate from server-rendered HTML.

## Web Component

`src/examples/web_component.gleam` defines its own counter and calls
`lustre.register(counter(), "lab-counter")`. It does not call start first.
Registration defines a custom element; the browser upgrades the two
`<lab-counter>` tags in `assets/index.html`. Each instance owns independent
state and resets on reload.

The component's lifecycle and DOM interface make it usable as an HTML element.
Attribute/property inputs and outgoing custom events are available but are not
configured in this lab. Separating definition and registration into two files
is optional; this example keeps them together.

Lustre renders into an open shadow root. In this version, stylesheet adoption
is enabled by default, so the document's Tailwind stylesheet is adopted inside
it. Ordinary CSS does not inherently cross shadow boundaries.

## Server components: same counter, different ownership

`server/src/counter.gleam` defines the counter used by both server transports.
The component is started with `lustre.start_server_component`, without a DOM
selector. Model, init, update, view, and log effects execute on the BEAM.

| Transport file | Route | Runtime ownership |
| --- | --- | --- |
| `server/src/per_connection.gleam` | `/ws` | Starts a counter in init_socket; stops it on disconnect |
| `server/src/shared_counter.gleam` | `/shared-ws` | Subscribes to an existing counter; removes only its subscription on disconnect |

`server/src/lustre_runtime_server.gleam` starts the shared counter once before
HTTP handling. Shared sockets receive the same runtime handle. Each registers
its own Subject; Lustre sends rendering updates to subscribers. A newly
connected client receives the current view.

The page uses `<lustre-server-component route="…">` and Lustre's supplied thin
browser runtime, served as `/runtime.mjs`. The browser does not run our BEAM
counter's update or view. It forwards events; the socket handlers decode and
forward runtime messages, then send JSON rendering patches back. The browser
applies patches inside the custom element's shadow DOM.

This page initially sends the shell and empty server-component elements.
Its interactive patch transport is separate from the SSR routes below.

## Network and lifetime experiments

Open the comparison page in two tabs. In DevTools, select Network → WS,
enable Preserve log, and inspect `/ws` or `/shared-ws` in the Messages pane.

| Experiment | What it demonstrates |
| --- | --- |
| Click a browser counter | Local updates produce no counter traffic |
| Click a per-connection server counter | Events go out and patches come back; the other tab has separate state |
| Click a shared counter | One server update reaches both clients |
| Reload one tab | Its per-connection counter resets; shared state survives on the server |
| Close one tab | The remaining shared client continues using the same runtime |
| Disconnect and reconnect | Inspect connection behavior and subscription lifetime; a new per-connection runtime starts at zero |
| Restart the server | All in-memory server models disappear; the new shared runtime starts at zero |

Before refreshing after a restart, inspect the client: its DOM may still display
an old count after the server process has disappeared. Observe whether the
connection recovers and the display changes, or whether a refresh is needed.
Visible HTML is not proof of a live connection or retained server state.
Shared means shared by connected clients, not saved permanently. There is no
persistent storage or custom restart supervision in this lab.

## SSR and browser startup

`server/src/ssr.gleam` calls `counter.view(0)` and uses `element.to_string` to
serialize it. The server sends a full HTML document using the shared stylesheet.
It does not start a counter runtime, call init/update, or execute counter effects.
The argument 0 is simply the value supplied to view for each request.

At `/ssr`, there are no scripts or WebSockets. View Page Source or inspect the
HTTP response to see the counter already present. JavaScript is unnecessary,
and clicks do nothing.

At `/ssr-interactive`, the page also loads `ssr_client.js` and generated shared
JavaScript chunks. `src/ssr_client.gleam` contains a matching copy of the server
view and counter arithmetic, with a browser log prefix. It starts only this
counter, using ordinary `lustre.start` on `#ssr-counter`.

In Lustre 5.7.1, startup virtualises the existing DOM, reconciles it immediately
with the first client view, and installs event handlers. Matching elements can
be reused; mismatches are patched. This is the hydration behavior explored here;
we do not use a separate hydration API. Inspect the dependency's
`build/packages/lustre/src/lustre/runtime/client/runtime.ffi.mjs` and
`vdom/virtualise.ffi.mjs` for the implementation.

The browser's init creates a fresh model at 0. HTML does not transfer a model or
connect this runtime to the shared BEAM counter. Subsequent update, view, and
logging execute in the browser. Reload resets it.

Try changing the client init to 5 and rebuilding: the response still contains 0,
but startup reconciles it to 5. Restore 0 afterward. Clicking changes the live
DOM while View Page Source still shows the original response. Disabling
JavaScript restores the static behavior of `/ssr`.

## Files, styling, and checks

`assets/index.html` is the comparison page shell. The SSR module generates its
own document. The root browser entry mounts the four constructor examples and
registers the Web Components; the SSR browser entry runs separately.

There is one CSS source, `src/lustre_runtime_lab.css`. Tailwind scans browser
Gleam, server Gleam, and HTML sources. Both browser entries are built together
so the project stylesheet is generated once. Bun uses the system installation;
Tailwind's compiler is cached under `.lustre/`.

`.gitignore` excludes root and server build directories, dist, .lustre, Erlang
output, and crash dumps. Both manifest.toml files stay tracked to lock versions.
No additional generated-file rule is needed for SSR.

From the root:

```sh
gleam format --check src
gleam check
gleam run -m lustre/dev build lustre_runtime_lab ssr_client
```

From `server/`:

```sh
gleam format --check src
gleam check
gleam build
```

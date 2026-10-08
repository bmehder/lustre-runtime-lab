# Lustre Runtime Lab

A deliberately small counter lab comparing Lustre constructors and, later,
rendering/runtime models. The constructor comparison and browser custom-element example are implemented.

## Run everything on one port

From the project root:

```sh
gleam run -m lustre/dev build
cd server
gleam run
```

Open http://localhost:1234. One BEAM HTTP server serves the entire comparison
page, its browser JavaScript and CSS, Lustre's server-component client runtime,
and the WebSocket endpoint. Stop with Ctrl+C. The old Lustre development server
and separate port 1235 are no longer needed.

`assets/index.html` is the only page shell. The browser entry starts four apps and
registers the two Web Components. The server component appears below those examples.
There is no shell runtime and no environment switch in the HTML. The browser
bundle calls main automatically; the HTML only needs a module script tag.

We retain two Gleam packages because the root targets JavaScript and `server/`
targets Erlang. That is a build boundary, not two websites or two listening ports.

After browser code, HTML, or stylesheet edits, rebuild from the root and refresh
the browser. After server-code edits, restart `gleam run` from `server/`.
This setup serves built files and does not provide automatic development reloads.

## Compare the implementations

| File | Constructor | Counter behavior |
| --- | --- | --- |
| `src/examples/element.gleam` | `lustre.element(view())` | Static zero, disabled buttons, no counter model or messages |
| `src/examples/simple.gleam` | `lustre.simple(init, update, view)` | Model and pure update function |
| `src/examples/application.gleam` | `lustre.application(init, update, view)` | Logs each new count through an effect |
| `src/examples/component.gleam` | `lustre.component(init, update, view, [])` | Same logging effect, plus component configuration |

The interactive examples each keep an Int model and increment/decrement messages. Their
views are intentionally similar and their logic stays in each module so the
constructor signatures are easy to compare. Each interactive example exposes
`counter() -> lustre.App(Nil, Model, Msg)` to construct its definition, and its
`main()` starts that definition in a DOM container. This structure is identical
across simple, application, and component. There is no shared counter abstraction.

`simple` supplies empty effects internally. `application` makes effects explicit:
init and update return `#(Model, Effect(Msg))`. On each click, update computes the
next count and returns it with `effect.from(fn(_dispatch) { io.println(...) })`.
Lustre executes the callback to log the new count in the browser console.

The update function describes the side effect; it does not log directly. This
simple effect does not need to send a message back, so its dispatch parameter is
unused. All work happens in the browser; no timer or network request is involved.

`component` returns the same App type and adds component options. `counter()`
constructs its definition without starting it. It keeps the application example's
logging effect, using "Component counter" to distinguish the console output.
Our empty option list adds no behavior; `main` still starts it with `lustre.start`, like the other examples.

All three interactive examples have independent state and update loops. Having
its own loop does not uniquely distinguish a component from an application.
A registered custom element will introduce an element lifecycle, shadow DOM,
and an interface using attributes/properties and events. The separate Web Component example below now demonstrates that registration.

`element` supplies a fixed view without user-defined Model, Msg, init, or update.
We still mount it through `lustre.start`; internally Lustre constructs an App
with Nil state and a trivial update function. It is not SSR or HTML sent by a
server, and its disabled buttons dispatch nothing.

## Execution boundaries

Gleam compiles the examples to JavaScript. Each browser runtime holds its own
state, and runs init, update, and view locally. Counter clicks send no application
traffic to the server. Changing one counter does not change the others. Reload
resets all interactive counters to zero.

Lustre development tooling builds the browser JavaScript and CSS. The BEAM
server serves those files and owns the server counter. Only the server-counter
interactions cross the WebSocket; browser-counter interactions stay local.
The browser examples have no server-owned state. The separate server example
below adds a counter and WebSocket transport; shared state and SSR remain later.

## Styling and generated files

There is one CSS source: `src/lustre_runtime_lab.css`. Lustre detects and builds
Tailwind from this project entry. It scans the Gleam sources and
`assets/index.html` and the server counter view. Build through the default project
entry so all examples share one stylesheet.

Bun is configured to use the existing installation on PATH. Tailwind uses the
standalone compiler cached by Lustre in `.lustre/`. The browser receives CSS;
Tailwind does not participate in the runtime message loop.

`.gitignore` excludes `build/`, `dist/`, `.lustre/`, Erlang output, and crash dumps.
Keep `manifest.toml` tracked to lock dependency versions.

## Checks

```sh
gleam format --check src
gleam check
gleam run -m lustre/dev build
```

## Step 3: browser Web Component

`src/examples/web_component.gleam` contains its own Model, Msg, init, update,
view, and counter definition for direct comparison. Its main calls:

```gleam
lustre.register(counter(), "lab-counter")
```

It does not call `lustre.start`. Registration defines an HTMLElement subclass
through the browser's customElements registry. The browser upgrades the two
`<lab-counter>` tags already present in `assets/index.html`. Each element creates
its own runtime with an initial model of zero. Its counter logic and console-log
effect mirror `component.gleam`, with a distinct label and log prefix. We duplicate
the implementation intentionally so each example is self-contained.

A Web Component does not need to be started with `lustre.start` first. One module
can both define and register it. Separate definition and registration modules are
useful when multiple entry points need the same definition; they are not required.
`lustre.start` is only how our separate component example previews its definition
as an ordinary browser application.

All counter code still runs as JavaScript in the browser. Each custom element
holds separate runtime state. Click messages, view reconciliation, and console
logs stay local; no counter data goes to the BEAM or across the network.

Lustre renders inside each element's shadow root. In this installed version,
shadow roots are open and stylesheet adoption is enabled by default, so the
existing document Tailwind styles are adopted inside them. This is Lustre
behavior: ordinary page styles do not inherently cross a shadow boundary.
No new stylesheet, dependency, or ignore rule is needed.

Try changing A and checking that B and the original component counter stay at
zero. Inspect a `<lab-counter>` in browser developer tools and expand its
`#shadow-root (open)` to see the rendered card. Inspect the compiled
`examples/web_component.mjs` and Lustre's `runtime/client/component.ffi.mjs` to
follow registration and the custom-element lifecycle. The build tool combines
the browser code into one bundle, which our BEAM server serves. Gleam's
component definition alone does not generate a separate HTML template.

Reloading creates new element instances at zero. Attribute/property inputs and
outgoing custom events are not configured yet. The next section adds a server component. Shared server state and SSR remain
later steps.

Official APIs:
- https://lustre.hexdocs.pm/lustre.html#register
- https://lustre.hexdocs.pm/lustre/component.html#adopt_styles

## Step 4: server component on the BEAM

The separate `server/` Gleam package targets Erlang. Keeping a separate package
preserves the browser examples and avoids mixing browser and server entry points.
The duplicated `server/src/counter.gleam` uses the same component definition,
Model, Msg, update, view, and logging effect. Its runtime is started through
`lustre.start_server_component`, with no DOM selector.

Use the root build and server startup commands above. Run the server from
`server/`, because its file routes read the root `dist/` directory.

The common HTML shell contains both `<lab-counter>` tags and a
`<lustre-server-component route="/ws">` tag. The latter loads Lustre's supplied
thin browser runtime from `/runtime.mjs`; it does not load our server counter's
Model, update, or view as browser JavaScript. Lustre's dependency `priv/` directory
still supplies this prebuilt runtime; we no longer need a separate page under
`server/priv/`.

Each WebSocket connection starts a fresh BEAM counter process. Model, init,
update, view, and the logging effect execute there. Logs appear in the server
terminal. The thin browser runtime forwards event information to `/ws`; our
socket handler decodes it and forwards Lustre runtime messages. Lustre produces
DOM patches, which our handler encodes as JSON and sends to the browser.
The browser applies those patches inside the element's shadow DOM.

Reloading or reconnecting gets a new counter at zero. Disconnecting shuts down
that connection's counter. Multiple tabs do not share a counter in this step.
We will change state ownership to support multiple clients sharing one runtime
in the next step; do not infer shared state merely from running on a server.

This is interactive server rendering through patches, not our later SSR/hydration
experiment. Server-side HTML here provides only the shell and empty client element.

Checks from `server/`: `gleam format --check src`, `gleam check`, `gleam build`.
Track `server/manifest.toml`; ignore `server/build/`.

Official starting point:
https://github.com/lustre-labs/lustre/tree/main/examples/06-server-components/01-basic-setup

## Step 5: multiple clients, one shared server counter

`server/src/counter.gleam` is the single counter definition, containing Model,
Msg, init, update, view, and the logging effect. Both server examples use it.

`server/src/per_connection.gleam` starts `counter.counter()` inside init_socket
and shuts down that runtime on disconnect. `server/src/shared_counter.gleam`
receives an existing runtime and removes only the socket subscription on disconnect.
Neither transport module defines a different counter. Compare their connect,
init_socket, Socket, and close_socket functions to see the ownership difference.

The server entry starts `counter.counter()` once for the shared route, then
handles file serving and routes. Its shared runtime's lifetime belongs to the
whole server. Both cards deliberately render the same view and log prefix; their
surrounding page sections identify how each runtime is owned.
The original per-connection example remains at `/ws`; the new section connects
to `/shared-ws`. Both appear on the same page and use the same server port.

The server entry starts the shared runtime once, before starting HTTP handling,
and passes its handle to every shared WebSocket connection. Each socket registers
its own Subject with that runtime. One click produces one server update and one
server log; Lustre broadcasts rendering updates to all subscribers. A newly
connected client gets the current view of the existing model.

On disconnect, the shared example deregisters only that socket's Subject. It
never shuts down the shared runtime. The model survives a reload and even the
absence of all clients, while the BEAM server remains running. A server restart
creates a new model at zero; there is no persistence or restart supervision yet.

Compare with the previous section: its counter is created inside per_connection.init_socket and
is stopped when that connection closes. Its state is separate in every tab.

Try two tabs. Change the shared counter in either; both should display the same
count. Reload one: its per-connection counter resets, while its shared counter
receives the existing count. Close one tab and keep clicking in the other.

The network boundary is unchanged: browser event information goes to the server,
where update and view run, and JSON DOM patches come back. Client sharing is a
state-ownership choice, not a change to the counter's arithmetic or transport.
Stop here before inspecting frames and experimenting with forced disconnects,
reconnection, and server restarts in detail.

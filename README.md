# Lustre Runtime Lab

A deliberately small counter lab comparing Lustre constructors and, later,
rendering/runtime models. The constructor comparison and browser custom-element example are implemented.

## Run

```sh
gleam run -m lustre/dev start
```

Open http://localhost:1234/index.html. Stop with Ctrl+C. If the port is occupied, pass
`--port=1235` and open that port instead.

`assets/index.html` contains the static page shell and four mount elements.
The Gleam project entry only starts the four examples. The Web Component example also registers the two custom elements below them.
There is no shell runtime. `gleam.toml` contains configuration only.

Lustre serves custom assets at `/index.html` during development. Its automatically
generated `/` page is not used for this lab. The HTML imports the compiled Gleam
entry directly and calls `main()`. The development reload script watches for
changes. There is no mode flag, bundle probe, or production loader.

This HTML is deliberately for the development server. The build command checks
bundling and CSS generation, but the copied HTML in `dist/` is not yet a standalone
production page. We will handle production HTML when deployment becomes relevant.

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

The development tooling runs on the BEAM, bundles and serves files, and watches
source changes. Development reload traffic is separate from counter messages.
No server counter, shared state, WebSocket transport, or SSR is implemented.

## Styling and generated files

There is one CSS source: `src/lustre_runtime_lab.css`. Lustre detects and builds
Tailwind from this project entry. It scans the Gleam sources and
`assets/index.html`. Run the comparison page through the default project entry, rather
than using the old per-example development commands.

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
follow registration and the custom-element lifecycle. The dev server serves
modules; the build tool combines the code into a browser bundle. Gleam's
component definition alone does not generate a separate HTML template.

Reloading creates new element instances at zero. Attribute/property inputs and
outgoing custom events are not configured yet. Server components, shared server
state, and SSR remain later steps; stop here to inspect the browser component.

Official APIs:
- https://lustre.hexdocs.pm/lustre.html#register
- https://lustre.hexdocs.pm/lustre/component.html#adopt_styles

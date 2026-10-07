# Lustre runtime exploration

## Step 1: ordinary browser application

```sh
gleam run -m lustre/dev start
```

Open http://localhost:1234. Use + and − to change the counter.
Stop the development server with Ctrl+C.

Port 1234 was already occupied during setup, so the verified preview runs at
http://localhost:1235 using:

```sh
gleam run -m lustre/dev start --port=1235
```

This setup uses the existing Bun installation (`bun` on PATH) to bundle JavaScript,
configured in `gleam.toml`, rather than downloading another copy.

The ordinary application is in `src/examples/ordinary.gleam`. The project entry
`src/lustre_runtime_lab.gleam` just starts that example:

- `Model` is an alias for `Int`, the counter's only state.
- `init` starts at zero. `Nil` means no startup configuration is needed.
- `Msg` describes the two button clicks.
- `update` returns the next model.
- `view` returns an `Element(Msg)`: a UI description with message-producing handlers.
- `main` connects these with `lustre.simple` and mounts in the generated HTML's `#app`.

Gleam compiles this application to JavaScript. The browser runs `main`, `init`,
`update`, and `view`. Lustre's browser runtime holds the current model, handles
messages, and reconciles the view with the DOM. `view` describes elements;
it does not directly mutate the DOM.

The development tooling runs on the BEAM, builds and serves HTML and JavaScript,
and watches for source changes. It does not own the counter state. Counter clicks
send no requests or WebSocket messages to the server. Development reload traffic
is separate from application behavior.

Try two tabs: each has an independent counter. Reloading starts at zero again;
there is no persistence.

## Organization

Keep one project with a separate module under `src/examples/` for each strategy.
Preserve `ordinary.gleam` as the baseline and add later examples alongside it,
rather than replacing it. Keep each example's Model, Msg, update, and view visible
so their runtime differences are easy to compare. We will add server directories
only if separate build targets/processes make them useful, and keep SSR separate.
No later stages are implemented yet.

## Styling

`src/lustre_runtime_lab.css` imports Tailwind v4 and explicitly scans the Gleam
sources for utility classes. Lustre's development tools compile and include the
CSS automatically. Tailwind runs at build time; the browser receives ordinary CSS.
It does not change where state lives or how messages travel.

Future examples can use the same visual design. When we introduce a custom element,
we will check its shadow DOM boundary: page-level styles do not automatically
style elements inside a shadow root.

## Checks

```sh
gleam format --check src
gleam check
gleam run -m lustre/dev build
```

Official guide: https://lustre.hexdocs.pm/guide/01-quickstart.html
# lustre-runtime-lab

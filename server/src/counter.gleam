import gleam/int
import gleam/io
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model =
  Int

pub type Msg {
  UserClickedIncrement
  UserClickedDecrement
}

/// Construct the counter without choosing where it will run.
pub fn counter() -> lustre.App(Nil, Model, Msg) {
  lustre.component(init, update, view, [])
}

fn init(_args: Nil) -> #(Model, Effect(Msg)) {
  #(0, effect.none())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let next = case msg {
    UserClickedIncrement -> model + 1
    UserClickedDecrement -> model - 1
  }

  #(
    next,
    effect.from(fn(_dispatch) {
      io.println("Server counter: " <> int.to_string(next))
    }),
  )
}

fn view(model: Model) -> Element(Msg) {
  html.div(
    [
      attribute.class("h-full"),
    ],
    [
      html.section(
        [
          attribute.class(
            "h-full w-full rounded-2xl bg-white p-8 shadow-sm ring-1 ring-slate-200",
          ),
        ],
        [
          html.p([attribute.class("text-sm font-medium text-indigo-600")], [
            html.text("lustre.component on the BEAM"),
          ]),
          html.h2([attribute.class("mt-2 text-2xl font-semibold")], [
            html.text("Counter"),
          ]),
          html.p([attribute.class("mt-2 text-sm text-slate-500")], [
            html.text("State, update, view, and logging run on the BEAM."),
          ]),
          html.div(
            [attribute.class("mt-8 flex items-center justify-between gap-6")],
            [
              html.button(
                [
                  attribute.class(
                    "h-12 w-12 rounded-xl bg-slate-100 text-xl font-medium hover:bg-slate-200 focus-visible:outline-2 focus-visible:outline-indigo-600",
                  ),
                  attribute.attribute("aria-label", "Decrement"),
                  event.on_click(UserClickedDecrement),
                ],
                [html.text("−")],
              ),
              html.p(
                [
                  attribute.class("text-5xl font-semibold tabular-nums"),
                  attribute.attribute("aria-live", "polite"),
                ],
                [html.text(int.to_string(model))],
              ),
              html.button(
                [
                  attribute.class(
                    "h-12 w-12 rounded-xl bg-indigo-600 text-xl font-medium text-white hover:bg-indigo-700 focus-visible:outline-2 focus-visible:outline-indigo-600 focus-visible:outline-offset-2",
                  ),
                  attribute.attribute("aria-label", "Increment"),
                  event.on_click(UserClickedIncrement),
                ],
                [html.text("+")],
              ),
            ],
          ),
        ],
      ),
    ],
  )
}

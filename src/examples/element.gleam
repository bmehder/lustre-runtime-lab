import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn main() -> Nil {
  let app = lustre.element(view())
  let assert Ok(_) = lustre.start(app, "#element", Nil)
  Nil
}

fn view() -> Element(Nil) {
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
            html.text("01 · lustre.element"),
          ]),
          html.h2([attribute.class("mt-2 text-2xl font-semibold")], [
            html.text("Counter"),
          ]),
          html.p([attribute.class("mt-2 text-sm text-slate-500")], [
            html.text("A static view: no counter state or messages."),
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
                  attribute.disabled(True),
                ],
                [html.text("−")],
              ),
              html.p(
                [
                  attribute.class("text-5xl font-semibold tabular-nums"),
                  attribute.attribute("aria-live", "polite"),
                ],
                [html.text("0")],
              ),
              html.button(
                [
                  attribute.class(
                    "h-12 w-12 rounded-xl bg-indigo-600 text-xl font-medium text-white hover:bg-indigo-700 focus-visible:outline-2 focus-visible:outline-indigo-600 focus-visible:outline-offset-2",
                  ),
                  attribute.attribute("aria-label", "Increment"),
                  attribute.disabled(True),
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

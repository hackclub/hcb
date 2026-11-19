# Modals

A modal is a native `<dialog>`, rendered by the `modal` helper (`app/helpers/modal_helper.rb`) and opened by any element that names it:

```erb
<%= link_to "Rename", "#", data: { modal: "rename_card" } %>

<%= modal "Name your card", id: "rename_card" do %>
  <%= render "stripe_cards/rename_form", stripe_card: %>
<% end %>
```

That's the whole API. The browser draws the modal above everything else, traps focus inside it, closes the top one on Escape and hands focus back to the trigger. `app/javascript/modal.js` adds what it doesn't do: opening from triggers, closing from the backdrop, and the edge cases below. It listens once on the document, so a page can render hundreds of modals (one per transaction row, say) without any setup per modal.

## Options

| Option | |
| --- | --- |
| `title` (first argument) | Renders the header with a close button. Leave it out to write your own header, using `modal_close` for the button. |
| `id:` | Required. What triggers point at. |
| `size:` | `:wide` or `:huge`. |
| `external_link:` | Adds an "open in new tab" link to the header. |
| `open: true` | Opens it as soon as it's rendered, including when a Turbo Stream or frame adds it. |
| anything else | `class:`, `data:`, `style:` and the like land on the `<dialog>`. Classes and Stimulus controllers are added to the modal's own. |

## Opening and closing

- **Triggers** are any element with `data-modal="<id>"`. A link inside a trigger (a row, say) still does its own thing, and Cmd/Ctrl-clicking a trigger that's a real link opens the link.
- **Close** with an element marked `data-modal-close`, Escape, the backdrop, or `dialog.close()` from a Stimulus controller: `this.element.closest('dialog').close()`.
- **From JavaScript**, `import { openModal } from '../modal'` and call `openModal('rename_card')` (or pass the element).
- **From the server**, `turbo_stream.open_modal("rename_card")`.
- **To close after a successful form submission**, add `data: { controller: "turbo-frame-modal", action: "turbo:submit-end->turbo-frame-modal#submitEnd" }`.

## Nesting

Open a modal from inside another and it stacks on top. Escape and the backdrop close only the top one, and closing a modal closes any opened from inside it, so a hidden child can never be left blocking the page.

## Where to render a modal

Anywhere, even in a table row, a hidden menu or a lazy turbo-frame. A modal opens from the end of `<body>` and moves back when it closes, so where it's rendered never changes how it looks or behaves: it doesn't inherit styles from the row around it, and its links and forms navigate the page rather than the frame. If the frame it came from is replaced while it's open, it's dropped when it closes.

While it's open, it isn't inside its original ancestors, so Herb state and forms around it don't reach it. Keep a modal's reactive state in a partial rendered inside it, and don't render a modal with its own `<form>` inside another form (HTML can't nest forms, so the inner one is dropped when the page is parsed).

## Things that render outside a modal

While a modal is open, the rest of the page is inert. Two things that render to `<body>` handle this already:

- **Menus** (`menu` controller) opened from inside a modal render inside it.
- **SweetAlert** (`swal`, `data-turbo-confirm`) gets a top-layer dialog of its own. Import it from `common/swal`, not `sweetalert`.

Anything new that portals to `<body>` needs the same treatment.

## The transaction popover

`application/_shared_popover` is one modal, slid in from the right, that `PopoverHelper` links load a transaction, card or payment into. Its `popover` controller keeps the record's URL in `?popover=`, so a reload reopens it and Back closes it.

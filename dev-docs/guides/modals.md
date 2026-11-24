# Modals

A modal is a native `<dialog>`, rendered by the `modal` helper (`app/helpers/modal_helper.rb`) and opened by any element that names it:

```erb
<%= link_to "Rename", "#", data: { modal: "rename_card" } %>

<%= modal "Name your card", id: "rename_card" do %>
  <%= render "stripe_cards/rename_form", stripe_card: %>
<% end %>
```

That's the whole API. `app/javascript/modal.js` opens it with `show()`, not `showModal()`, and does what `showModal()` would have done itself: a backdrop (`.modal-backdrop`, placed right before the modal) covers the page, each modal opened stacks above the last, focus stays inside the top one (Tab wraps around, and anything behind that takes focus hands it back), and `aria-modal` tells screen readers the page behind is out of reach. The browser still focuses the first control and hands focus back to the trigger on close. It also opens from triggers, closes from the backdrop, and handles the edge cases below.

Why not `showModal()`: it makes the rest of the page inert, and the browser restyles the whole page to do that, once on open and again on close. On a long ledger that was most of what a click cost.

It all listens once on the document, so a page can render hundreds of modals (one per transaction row, say) without any setup per modal.

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
- **Close** with an element marked `data-modal-close`, Escape or the backdrop. Each animates the modal out first.
- **From JavaScript**, `import { openModal, closeModal } from '../modal'` and call `openModal('rename_card')` or `closeModal(this.element.closest('dialog'))` (an id or the element). `dialog.close()` works too, but skips the animation.
- **From the server**, `turbo_stream.open_modal("rename_card")`.
- **To close after a successful form submission**, add `data: { controller: "turbo-frame-modal", action: "turbo:submit-end->turbo-frame-modal#submitEnd" }`.

## Nesting and Escape

Open a modal from inside another and it stacks on top. The backdrop closes only the top one, and closing a modal also closes any opened from it (from a trigger inside it, or rendered inside it), so none is left behind blocking the page. Opening a modal that's already open (the popover loading another record, say) closes the ones opened from it, so they don't cover what it shows now.

Escape closes one thing at a time, newest first: with the popover, a modal over it and a menu open in that, three presses close the menu, the modal, then the popover. Modals and menus join this stack (`app/javascript/layers.js`) while they're open:

```js
import { addLayer, removeLayer } from '../layers'

addLayer(this, () => this.close()) // on open
removeLayer(this) // on close
```

Something that handles Escape on its own, like a combobox closing its suggestions or an inline edit cancelling, calls `event.preventDefault()`, and the stack leaves that press alone.

## Where to render a modal

Anywhere, even in a table row, a hidden menu or a lazy turbo-frame. A modal opens from the end of `<body>` and moves back when it closes, so where it's rendered never changes how it looks or behaves: it doesn't inherit styles from the row around it, and its links and forms navigate the page rather than the frame. If the frame it came from is replaced while it's open, it's dropped when it closes. If it's removed or replaced while open (by a Turbo Stream, say), its backdrop and the modals opened from it go with it.

While it's open, it isn't inside its original ancestors, so Herb state and forms around it don't reach it. Keep a modal's reactive state in a partial rendered inside it, and don't render a modal with its own `<form>` inside another form (HTML can't nest forms, so the inner one is dropped when the page is parsed).

## Look and motion

Modals, the popover, SweetAlert and menus are styled as one family, so anything new that floats over the page should reuse the same pieces:

- **Corners**: `--radius-2xl` for anything with a backdrop (modals, the popover, alerts), `--radius-xl` for menus. On phones, what slides up from the bottom uses `$sheet-radius`.
- **Backdrop**: `$backdrop`, or `$backdrop-dark` in dark mode.
- **Shadow**: `--shadow-modal` or `--shadow-menu`; `_dark.scss` swaps both for dark mode.
- **Motion**: everything fades in with a small scale or slide (0.2s for modals and alerts, 0.15s for menus) and leaves the same way in reverse, rather than disappearing. Leaving takes 0.15s everywhere, so closing never feels slower than opening.

## Performance

A ledger page can hold hundreds of triggers, modals and menus, so none of them may cost anything until one is used:

- **Triggers and closed modals** have no listeners or controllers of their own. The listeners in `modal.js` and `layers.js` are attached once, to the document.
- **Something that reacts to the whole page** (outside clicks, Escape, `hcb:close-menus`) listens only while it's open. Menus add their document listeners in `open()` and remove them in `close()`. A `click@document->...` action would instead run on every click, for every instance on the page.
- **Opening a modal** touches only the modal and its backdrop. Don't make the page behind `inert` or open with `showModal()`: either restyles the whole page (~15–25 ms per open and per close on a 75-row ledger at 4× CPU).
- **Page-wide behaviors** (tooltips, money inputs) are delegated from the document once. Don't rebind them on `turbo:frame-load` or watch the whole page with a `MutationObserver`; each popover load would stack more handlers onto every click.

## Things that render outside a modal

Modals sit at `z-index: 2000` and up, under the backdrop of the one above. While one is open, focus can't leave it. What renders to `<body>` handles this already:

- **Menus** (`menu` controller) opened from inside a modal render inside it.
- **SweetAlert** (`swal`, `data-turbo-confirm`) shows above every modal and joins the top of the Escape stack. Import it from `common/swal`, not `sweetalert`.
- **The command bar** shows above every modal and is marked `data-above-modals`, so the focus trap lets it keep focus.

Anything new that portals to `<body>` while a modal is open needs a `z-index` above 2000 and `data-above-modals` (if it takes focus), plus a layer if Escape should close it.

## The transaction popover

`application/_shared_popover` is one modal, slid in from the right, that `PopoverHelper` links load a transaction, card or payment into. Its `popover` controller keeps the record's URL in `?popover=`, so a reload reopens it and Back closes it.

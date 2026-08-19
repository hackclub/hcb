import { Controller } from '@hotwired/stimulus'

// Toggles a transaction's memo between a read-only display and an inline
// rename form entirely client-side — the current memo is already in the DOM,
// so entering edit mode never needs a request. The only network round trip
// is the actual save (a Turbo Stream PATCH), which updates every occurrence
// of this item's memo on the page and hands control back to whichever
// instance of this controller triggered it.
export default class extends Controller {
  static targets = ['display', 'form', 'input']

  editOnShiftClick(e) {
    if (!e.shiftKey) return

    e.preventDefault()
    e.stopImmediatePropagation()

    this.displayTarget.hidden = true
    this.formTarget.hidden = false
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  cancel() {
    this.inputTarget.value = this.inputTarget.defaultValue
    this.showDisplay()
  }

  keydown(e) {
    if (e.key === 'Escape') this.cancel()
  }

  save() {
    this.formTarget.requestSubmit()
  }

  submitEnd(e) {
    if (!e.detail.success) return

    // The value just saved becomes the new baseline an Escape reverts to,
    // so cancelling a later edit doesn't jump back to the pre-rename text.
    this.inputTarget.defaultValue = this.inputTarget.value

    this.showDisplay()
    this.flashRenamed()

    // The turbo_stream response just replaced the display span(s) with fresh
    // elements, which have no hover listener yet — ui.js only re-attaches
    // tooltips on turbo:load/turbo:frame-load, neither of which fires for a
    // plain (non-frame) form's stream response, so without this the tooltip
    // silently stops working until the next full page load.
    window.attachTooltipListener?.()
  }

  showDisplay() {
    this.formTarget.hidden = true
    this.displayTarget.hidden = false
  }

  flashRenamed() {
    this.displayTarget.classList.remove('renamed')
    void this.displayTarget.offsetWidth // restart the CSS animation
    this.displayTarget.classList.add('renamed')
  }
}

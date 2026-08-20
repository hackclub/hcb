import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['display', 'form', 'input', 'tooltip']

  connect() {
    this.tooltipObserver = new MutationObserver(() =>
      this.syncInputFromDisplay()
    )
    this.tooltipObserver.observe(this.tooltipTarget, { childList: true })
  }

  disconnect() {
    this.tooltipObserver?.disconnect()
  }

  syncInputFromDisplay() {
    const memo = this.tooltipTarget.textContent.trim()
    this.inputTarget.value = memo
    this.inputTarget.defaultValue = memo
    this.tooltipTarget.title = memo
  }

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
    // showDisplay's hidden toggle can force a blur that re-enters here; ignore it.
    if (this.closingForm) return

    this.formTarget.requestSubmit()
  }

  submitEnd(e) {
    if (!e.detail.success) return

    this.showDisplay()
    this.flashRenamed()
  }

  showDisplay() {
    // Hiding a still-focused input (e.g. after confirming with Enter) forces
    // a blur, which would otherwise re-trigger save() with a stale value.
    this.closingForm = true
    this.formTarget.hidden = true
    this.displayTarget.hidden = false
    this.closingForm = false
  }

  flashRenamed() {
    this.displayTarget.classList.remove('renamed')
    void this.displayTarget.offsetWidth // restart the CSS animation
    this.displayTarget.classList.add('renamed')
  }
}

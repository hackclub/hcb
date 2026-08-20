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
    this.formTarget.requestSubmit()
  }

  submitEnd(e) {
    if (!e.detail.success) return

    this.showDisplay()
    this.flashRenamed()
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

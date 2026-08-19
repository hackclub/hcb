import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['display', 'form', 'input', 'tooltip']

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

    this.inputTarget.defaultValue = this.inputTarget.value

    this.tooltipTarget.title = this.inputTarget.value

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

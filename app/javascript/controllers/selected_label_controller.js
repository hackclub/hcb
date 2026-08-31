import { Controller } from '@hotwired/stimulus'

// Mirrors a select's chosen option label into this element, and keeps it in step
// as the selection changes.
export default class extends Controller {
  static values = { from: String }

  connect() {
    this.select = document.getElementById(this.fromValue)
    if (!this.select) return

    this.listener = () => this.update()
    this.select.addEventListener('change', this.listener)
    this.update()
  }

  disconnect() {
    this.select?.removeEventListener('change', this.listener)
  }

  update() {
    this.element.textContent = this.select.selectedOptions[0]?.label ?? ''
  }
}

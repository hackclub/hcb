import { Controller } from '@hotwired/stimulus'

// Restores a button's label and clears its status colouring a moment after the
// server rendered it with an upload result.
export default class extends Controller {
  static targets = ['label']
  static classes = ['status']
  static values = {
    text: String,
    delay: { type: Number, default: 2000 },
  }

  connect() {
    this.timeout = setTimeout(() => this.reset(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  reset() {
    if (this.hasLabelTarget) this.labelTarget.textContent = this.textValue
    this.element.classList.remove(...this.statusClasses)
  }
}

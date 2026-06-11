import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { display: String, value: String, name: String }

  connect() {
    // Run after hw-combobox connects and sets up its targets
    setTimeout(() => {
      const hidden = this.element.querySelector(`[name="${this.nameValue}"][type="hidden"]`)
      if (!hidden) return

      if (this.valueValue) hidden.value = this.valueValue

      if (this.displayValue) {
        const visible = document.getElementById(hidden.id.replace(/-hw-hidden-field$/, ''))
        if (visible) visible.value = this.displayValue
      }
    }, 0)
  }
}

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { display: String, value: String, name: String }

  connect() {
    // this controller is a bug fix for the original gem hw-combobox,
    // which doesn't set the value of the hidden input on page load,
    // even if the value is present in the HTML.
    // this causes issues when the form is submitted without changing the combobox,
    // as the hidden input will be empty and the server will not receive the correct value.
    setTimeout(() => {
      const hidden = this.element.querySelector(
        `[name="${this.nameValue}"][type="hidden"]`
      )
      if (!hidden) return

      if (this.valueValue) hidden.value = this.valueValue

      if (this.displayValue) {
        const visible = document.getElementById(
          hidden.id.replace(/-hw-hidden-field$/, '')
        )
        if (visible) visible.value = this.displayValue
      }
    }, 0)
  }
}

import { Controller } from '@hotwired/stimulus'

// Guards the application's Continue button while an affiliation has been picked
// but not saved. Lives on the affiliation form so the shared affiliation partial
// stays free of page-specific wiring.
export default class extends Controller {
  static values = { button: String, message: String }

  update() {
    const button = document.getElementById(this.buttonValue)
    if (!button) return

    if (this.picked) {
      button.setAttribute('data-turbo-confirm', this.messageValue)
    } else {
      button.removeAttribute('data-turbo-confirm')
    }
  }

  // Once the affiliation has saved it isn't unsaved any more, so drop the
  // selection and let the dependent fields collapse with it.
  clear() {
    this.radios.forEach(radio => (radio.checked = false))
    this.dispatch('set', { detail: { key: 'type', value: '' } })
    this.update()
  }

  get radios() {
    return this.element.querySelectorAll('[data-conditional-fields-key="type"]')
  }

  get picked() {
    return Array.from(this.radios).some(radio => radio.checked && radio.value)
  }
}

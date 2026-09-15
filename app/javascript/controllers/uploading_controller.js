import { Controller } from '@hotwired/stimulus'

// Marks the upload button busy for the life of the request, so it can't be
// fired twice while the file is on its way up.
export default class extends Controller {
  static values = {
    button: String,
    text: { type: String, default: 'Uploading...' },
    icon: String,
  }

  start() {
    const button = this.element.querySelector(`#${this.buttonValue}`)
    if (!button) return

    button
      .querySelectorAll('span')
      .forEach(el => (el.textContent = this.textValue))
    if (this.hasIconValue) {
      button
        .querySelectorAll('b')
        .forEach(el => (el.textContent = this.iconValue))
    }
    button.setAttribute('disabled', 'disabled')
  }
}

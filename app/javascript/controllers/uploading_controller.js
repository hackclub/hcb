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

    // Kept so reset() can put the button back if the upload fails
    this.labels ||= [...button.querySelectorAll('span, b')].map(el => [
      el,
      el.textContent,
    ])

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

  // For forms that stay on the page when an upload fails, so it can be retried
  reset() {
    if (!this.labels) return

    this.labels.forEach(([el, text]) => (el.textContent = text))
    this.labels = null
    this.element
      .querySelector(`#${this.buttonValue}`)
      ?.removeAttribute('disabled')
    // ActiveStorage leaves the input disabled once the files are up
    this.element.querySelectorAll('input[type=file]').forEach(input => {
      input.disabled = false
      input.value = ''
    })
  }
}

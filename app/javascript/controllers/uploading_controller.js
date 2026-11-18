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
  async reset(e) {
    // A successful upload replaces the form. Wait for Turbo to render that, so
    // the button doesn't flash back to its idle state first.
    if (e?.type == 'turbo:submit-end') {
      await e.detail.fetchResponse?.responseHTML
      await new Promise(requestAnimationFrame)
      await new Promise(requestAnimationFrame)
      if (!this.element.isConnected) return
    }
    if (!this.labels) return

    this.labels.forEach(([el, text]) => (el.textContent = text))
    this.labels = null
    this.element
      .querySelector(`#${this.buttonValue}`)
      ?.removeAttribute('disabled')
    this.element.querySelectorAll('input[type=file]').forEach(input => {
      // ActiveStorage leaves the input disabled once the files are up, and
      // leaves their signed ids in hidden inputs that a retry would resend
      input.disabled = false
      input.value = ''
      this.element
        .querySelectorAll(`input[type=hidden][name="${input.name}"]`)
        .forEach(hidden => hidden.remove())
    })
  }
}

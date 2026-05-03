import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    text: String,
    confirmText: String,
  }

  copy(e) {
    navigator.clipboard.writeText(this.textValue)

    const button = e.currentTarget

    if (button.hasAttribute('aria-label')) {
      const previousLabel = button.getAttribute('aria-label')

      button.setAttribute('aria-label', 'Copied!')

      setTimeout(() => {
        button.setAttribute('aria-label', previousLabel)
      }, 1000)
    }

    if (this.hasConfirmTextValue) {
      const previousText = button.innerText
      button.innerText = this.confirmTextValue

      setTimeout(() => {
        button.innerText = previousText
      }, 1500)
    }
  }
}

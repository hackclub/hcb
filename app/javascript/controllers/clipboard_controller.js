import { Controller } from '@hotwired/stimulus'
import swal from 'sweetalert'

export default class extends Controller {
  static values = {
    text: String,
    confirmText: String,
    shareText: String,
  }

  // Hand the current URL to the OS share sheet, falling back to the clipboard on
  // browsers without one.
  share(e) {
    e.preventDefault()

    try {
      navigator.share({ text: this.shareTextValue, url: window.location.href })
    } catch {
      navigator.clipboard.writeText(window.location.href)
      swal('Copied!', 'URL copied to clipboard.', 'success')
    }
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

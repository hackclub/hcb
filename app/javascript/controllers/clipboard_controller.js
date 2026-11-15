import { Controller } from '@hotwired/stimulus'
import swal from 'sweetalert'

export default class extends Controller {
  // `label`: the part of the button to swap for the confirm text, where
  // replacing the whole button would drop its icon.
  static targets = ['label']

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
      const label = this.hasLabelTarget ? this.labelTarget : button
      const previousText = label.innerText
      label.innerText = this.confirmTextValue

      setTimeout(() => {
        label.innerText = previousText
      }, 1500)
    }
  }
}

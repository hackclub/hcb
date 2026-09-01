import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { email: String }

  sendEmail() {
    window.open(`mailto:${this.emailValue}`)
  }

  copyEmail() {
    navigator.clipboard.writeText(this.emailValue)

    // eslint-disable-next-line no-alert
    alert('Copied!')
  }
}

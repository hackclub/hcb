import { Controller } from '@hotwired/stimulus'
import submitForm from '../common/submitForm'
import showConfirm from '../confirm'

export default class extends Controller {
  static values = { email: String }

  sendEmail() {
    window.open(`mailto:${this.emailValue}`)
  }

  copyEmail(e) {
    navigator.clipboard.writeText(this.emailValue)

    const item = e.currentTarget
    const label = item.querySelector('span.ml1')

    label.innerText = 'Copied!'

    setTimeout(() => {
      label.innerText = 'Copy email'
    }, 1500)
  }

  async impersonate({ params: { url } }) {
    if (await showConfirm()) submitForm(url, {})
  }
}

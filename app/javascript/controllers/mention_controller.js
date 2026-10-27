import { Controller } from '@hotwired/stimulus'
import submitForm from '../common/submitForm'
import swal from 'sweetalert'

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

  impersonate({ params: { url } }) {
    swal({
      title: 'Are you sure?',
      buttons: true,
    }).then(() => submitForm(url, {}))
  }
}

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { email: String }

  sendEmail() {
    window.open(`mailto:${this.emailValue}`)
  }

  copyEmail(e) {
    navigator.clipboard.writeText(this.emailValue)
    
    const item = e.currentTarget
    const label = item.querySelector('span.ml1')
    
    const previousText = label.innerText
    label.innerText = 'Copied!'

    setTimeout(() => {
      label.innerText = previousText
    }, 1500)
  }
}

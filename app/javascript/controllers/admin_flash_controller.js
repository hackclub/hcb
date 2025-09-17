import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    this.dismissTimeout = setTimeout(this.dismiss.bind(this), 5000)
  }

  disconnect() {
    clearTimeout(this.dismissTimeout)
  }

  dismiss() {
    this.element.classList.add('flash--dismissed')
  }
}

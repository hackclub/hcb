import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['message']

  clear(event) {
    if (this.element.contains(event.target)) {
      this.messageTarget.textContent = ''
    }
  }
}

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['submit', 'hint']

  enableSubmit() {
    this.submitTarget.disabled = false

    if (this.hasHintTarget) {
      this.hintTarget.hidden = true
    }
  }
}

import { Controller } from '@hotwired/stimulus'

// Live "N more words required" hint for the application description, and the
// matching validation message so a short description can't be submitted.
export default class extends Controller {
  static targets = ['input', 'hint']
  static values = {
    minimum: { type: Number, default: 50 },
    validate: { type: Boolean, default: false },
  }

  connect() {
    this.update()
  }

  update() {
    const count = (this.inputTarget.value.match(/\S+/g) || []).length
    const remaining = this.minimumValue - count

    if (this.hasHintTarget) {
      this.hintTarget.textContent =
        remaining > 0
          ? `${remaining} more word${remaining > 1 ? 's' : ''} required`
          : ''
    }

    if (this.validateValue) {
      this.inputTarget.setCustomValidity(
        count < this.minimumValue
          ? `Please enter at least ${this.minimumValue} words`
          : ''
      )
    }
  }
}

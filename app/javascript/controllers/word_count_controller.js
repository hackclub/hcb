import { Controller } from '@hotwired/stimulus'

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

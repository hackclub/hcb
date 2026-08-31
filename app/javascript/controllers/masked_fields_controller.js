import { Controller } from '@hotwired/stimulus'

// Bank details come back from the server masked. Focusing one clears the mask so
// a new number can be typed; leaving both blank puts the mask back and disables
// Save again.
export default class extends Controller {
  static targets = ['field', 'submit']
  static values = { editing: Boolean }

  connect() {
    this.render()
  }

  toggle() {
    if (!this.editingValue) {
      this.fieldTargets.forEach(field => (field.value = ''))
      this.editingValue = true
    } else if (this.fieldTargets.every(field => field.value === '')) {
      this.editingValue = false
      this.fieldTargets.forEach(
        field => (field.value = field.dataset.maskedRestore ?? '')
      )
    }

    this.render()
  }

  render() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = !this.editingValue
  }
}

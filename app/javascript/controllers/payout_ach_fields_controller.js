import { Controller } from '@hotwired/stimulus'

// The ACH fields render masked (••••1234) until the user focuses one. Focusing
// clears them for editing; blurring both while they are still empty puts the
// masked values back. When the stored numbers failed validation they are shown
// unmasked and there is nothing to restore, so the restore values are passed in
// separately rather than read from the inputs on connect.
export default class extends Controller {
  static targets = ['routingNumber', 'accountNumber', 'submit']
  static values = {
    routingNumber: String,
    accountNumber: String,
    editing: Boolean,
  }

  toggle() {
    if (!this.editingValue) {
      this.routingNumberTarget.value = ''
      this.accountNumberTarget.value = ''
      this.editingValue = true
    } else if (
      this.routingNumberTarget.value == '' &&
      this.accountNumberTarget.value == ''
    ) {
      this.editingValue = false
      this.routingNumberTarget.value = this.routingNumberValue
      this.accountNumberTarget.value = this.accountNumberValue
    }
  }

  editingValueChanged() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = !this.editingValue
  }
}

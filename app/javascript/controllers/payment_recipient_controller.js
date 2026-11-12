import { Controller } from '@hotwired/stimulus'

// The saved-recipient picker shared by the ACH, wire, and check transfer forms.
// The recipient itself lives in the form's Alpine component, so picking or
// clearing one is announced as `payment-recipient:change` with the recipient
// (or null) as the detail, which the form assigns to `payment_recipient`.
export default class extends Controller {
  static targets = ['debug']

  select({ params: { recipient } }) {
    this.change(recipient)
  }

  clear() {
    this.change(null)
  }

  change(recipient) {
    this.dispatch('change', { detail: recipient })

    if (this.hasDebugTarget) {
      this.debugTarget.textContent =
        'Debug info:\n\n' + JSON.stringify(recipient || {}, null, 2)
    }
  }
}

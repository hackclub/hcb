import { Controller } from '@hotwired/stimulus'

// Rejecting an invoice needs a reason, so "Reject" swaps the review buttons
// for a short form instead of submitting straight away.
export default class extends Controller {
  static targets = ['actions', 'rejection', 'reason']

  startRejecting() {
    this.swap(true)
    this.reasonTarget.focus()
  }

  cancelRejecting() {
    this.swap(false)
  }

  // Cmd/Ctrl+Enter submits, as it does for comments
  submitOnShortcut(event) {
    if (event.key !== 'Enter' || !(event.metaKey || event.ctrlKey)) return

    event.preventDefault()
    this.reasonTarget.form.requestSubmit()
  }

  swap(rejecting) {
    this.actionsTarget.hidden = rejecting
    this.rejectionTarget.hidden = !rejecting
  }
}

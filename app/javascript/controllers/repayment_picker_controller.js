/* global $ */
import { Controller } from '@hotwired/stimulus'

// The modal on the transfer form listing the recipient's transactions that can
// be repaid. The selection is announced as `repayment-picker:select`, which the
// transfer-type controller listens for on the document: opening the modal moves
// it out of the form.
export default class extends Controller {
  static targets = ['form', 'destination', 'frame']

  // A new recipient means a new set of transactions, so the filters for the old
  // one no longer apply.
  setDestination(destinationEventId) {
    this.formTarget.reset()
    this.destinationTarget.value = destinationEventId || ''
    this.dispatch('reset')

    if (destinationEventId) {
      const url = new URL(this.formTarget.action, window.location.origin)
      url.searchParams.set('destination_event_id', destinationEventId)
      this.frameTarget.src = url.toString()
    } else {
      this.frameTarget.removeAttribute('src')
    }
  }

  selectionChanged({ detail }) {
    this.dispatch('select', { detail })
  }

  done() {
    $.modal.close()
  }
}

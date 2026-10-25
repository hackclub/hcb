/* global $ */
import { Controller } from '@hotwired/stimulus'

const usd = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
})

// The modal on the transfer form listing the recipient's transactions that can
// be repaid. The selected ones are kept here, keyed by id, so paging or
// filtering the list doesn't lose them. "Done" announces them as
// `repayment-picker:select`, which the transfer-type controller listens for on
// the document: opening the modal moves it out of the form.
export default class extends Controller {
  static targets = ['form', 'destination', 'frame', 'row', 'summary']

  initialize() {
    this.selected = new Map()
  }

  // A new recipient means a new set of transactions, so the filters and
  // selection for the old one no longer apply.
  setDestination(destinationEventId) {
    this.formTarget.reset()
    this.destinationTarget.value = destinationEventId || ''
    this.seed([])

    if (destinationEventId) {
      const url = new URL(this.formTarget.action, window.location.origin)
      url.searchParams.set('destination_event_id', destinationEventId)
      this.frameTarget.src = url
    } else {
      this.frameTarget.removeAttribute('src')
    }
  }

  // Starts from what the form already has, so reopening the picker adds to or
  // changes that rather than starting over.
  seed(transactions) {
    this.selected = new Map(transactions.map(t => [String(t.id), t]))
    this.rowTargets.forEach(row => this.rowTargetConnected(row))
    this.render()
  }

  // Rows arrive with each page of the frame; mark the ones already chosen.
  rowTargetConnected(row) {
    row.classList.toggle(
      'selected__transaction',
      this.selected.has(row.dataset.repaymentPickerIdParam)
    )
  }

  toggle({ currentTarget, params: { id, memo, date, amount, amountLabel } }) {
    const key = String(id)
    if (this.selected.has(key)) {
      this.selected.delete(key)
    } else {
      this.selected.set(key, {
        id: key,
        memo: String(memo),
        date: String(date),
        amount: Number(amount).toFixed(2),
        amountLabel: String(amountLabel),
      })
    }
    currentTarget.classList.toggle(
      'selected__transaction',
      this.selected.has(key)
    )
    this.render()
  }

  done() {
    this.dispatch('select', {
      detail: { transactions: [...this.selected.values()] },
    })
    $.modal.close()
  }

  render() {
    const transactions = [...this.selected.values()]
    const cents = transactions.reduce(
      (sum, t) => sum + Math.round(Number(t.amount) * 100),
      0
    )
    this.summaryTarget.textContent = transactions.length
      ? `${transactions.length} selected · ${usd.format(cents / 100)}`
      : 'None selected'
  }
}

/* global $ */
import { Controller } from '@hotwired/stimulus'

// The modal on the transfer form listing the recipient's transactions that can
// be repaid. The selection is announced as `repayment-picker:select`, which the
// transfer-type controller listens for on the document: opening the modal moves
// it out of the form.
export default class extends Controller {
  static targets = ['form', 'destination', 'frame', 'checkbox', 'summary']
  static values = { transactions: Array }

  connect() {
    this.refresh()
  }

  checkboxTargetConnected(checkbox) {
    checkbox.checked = this.transactionsValue.some(
      transaction => transaction.id === checkbox.dataset.repaymentPickerIdParam
    )
  }

  // A new recipient means a new set of transactions, so the filters for the old
  // one no longer apply.
  setDestination(destinationEventId) {
    this.formTarget.reset()
    this.destinationTarget.value = destinationEventId || ''
    this.clear()

    if (destinationEventId) {
      const url = new URL(this.formTarget.action, window.location.origin)
      url.searchParams.set('destination_event_id', destinationEventId)
      this.frameTarget.src = url.toString()
    } else {
      this.frameTarget.removeAttribute('src')
    }
  }

  pick({ target, params: { id, memo, date, amount } }) {
    const transactions = this.transactionsValue.filter(
      transaction => transaction.id !== String(id)
    )
    if (target.checked)
      transactions.push({
        id: String(id),
        memo: String(memo),
        date: String(date),
        amount: Number(amount).toFixed(2),
      })
    this.transactionsValue = transactions
    this.refresh()
  }

  clear() {
    this.transactionsValue = []
    this.refresh()
  }

  refresh() {
    this.checkboxTargets.forEach(checkbox =>
      this.checkboxTargetConnected(checkbox)
    )
    const transactions = this.transactionsValue
    const cents = transactions.reduce(
      (sum, transaction) => sum + Math.round(Number(transaction.amount) * 100),
      0
    )
    const total = new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(cents / 100)
    this.summaryTarget.textContent = `${transactions.length} selected · ${total}`
    this.dispatch('select', { detail: transactions })
  }

  done() {
    $.modal.close()
  }
}

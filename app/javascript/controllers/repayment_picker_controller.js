/* global $ */
import { Controller } from '@hotwired/stimulus'

const usd = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
})

// The modal on the transfer form listing the recipient's transactions that can
// be repaid. The selected ones are kept here, keyed by id, so paging or
// filtering the list doesn't lose them, and listed in the modal's footer.
// "Done" announces them as `repayment-picker:select`, which the transfer-type
// controller listens for on the document: opening the modal moves it out of the
// form.
export default class extends Controller {
  static targets = [
    'form',
    'destination',
    'frame',
    'row',
    'summary',
    'selectedList',
    'selectedTemplate',
    'doneButton',
  ]

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
      this.frameTarget.src = url.toString()
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
    this.markRow(row, this.selected.has(row.dataset.repaymentPickerIdParam))
  }

  // Bound to the row, so a click on its Select button lands here too.
  toggle(event) {
    const row = event.currentTarget
    const { id, memo, date, amount, amountLabel } = event.params
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
    this.markRow(row, this.selected.has(key))
    this.render()
  }

  remove(event) {
    const id = String(event.params.id)
    const item = event.currentTarget.closest('li')
    const next = item.nextElementSibling || item.previousElementSibling

    this.selected.delete(id)
    const row = this.rowTargets.find(
      row => row.dataset.repaymentPickerIdParam === id
    )
    if (row) this.markRow(row, false)
    this.render()

    // The removed item's button is gone; keep focus in the list if possible.
    const nextId = next?.dataset.id
    const focusTarget =
      (nextId &&
        this.selectedListTarget.querySelector(
          `li[data-id="${CSS.escape(nextId)}"] button`
        )) ||
      this.doneButtonTarget
    focusTarget.focus()
  }

  done() {
    this.dispatch('select', {
      detail: { transactions: [...this.selected.values()] },
    })
    $.modal.close()
  }

  markRow(row, selected) {
    const button = row.querySelector('button[aria-pressed]')
    if (!button) return
    button.setAttribute('aria-pressed', String(selected))
    button.classList.toggle('bg-success', selected)
  }

  render() {
    const transactions = [...this.selected.values()]
    const cents = transactions.reduce(
      (sum, t) => sum + Math.round(Number(t.amount) * 100),
      0
    )

    if (this.hasSummaryTarget) {
      this.summaryTarget.textContent = transactions.length
        ? `${transactions.length} selected · ${usd.format(cents / 100)}`
        : 'None selected'
    }

    if (this.hasSelectedListTarget && this.hasSelectedTemplateTarget) {
      this.selectedListTarget.replaceChildren(
        ...transactions.map(t => this.selectedItem(t))
      )
      this.selectedListTarget.hidden = transactions.length === 0
    }
  }

  selectedItem(transaction) {
    const item =
      this.selectedTemplateTarget.content.firstElementChild.cloneNode(true)
    item.dataset.id = transaction.id
    item.querySelector('[data-field="memo"]').textContent = transaction.memo
    item.querySelector('[data-field="memo"]').title = transaction.memo
    item.querySelector('[data-field="amountLabel"]').textContent =
      transaction.amountLabel

    const button = item.querySelector('button')
    button.dataset.repaymentPickerIdParam = transaction.id
    button.setAttribute(
      'aria-label',
      `Remove ${transaction.memo}, ${transaction.amountLabel}`
    )
    return item
  }
}

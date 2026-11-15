import { Controller } from '@hotwired/stimulus'

import { USDollar } from '../common/money'

export default class extends Controller {
  static targets = ['checkbox', 'summary', 'review', 'list', 'template']
  static values = { transactions: Array }

  connect() {
    this.refresh()
  }

  checkboxTargetConnected(checkbox) {
    checkbox.checked = this.transactionsValue.some(
      transaction =>
        transaction.id === checkbox.dataset.transactionSelectionIdParam
    )
  }

  toggleRow({ target, currentTarget }) {
    if (target.closest('a, button, input, label, select, textarea')) return

    currentTarget
      .querySelector('[data-transaction-selection-target="checkbox"]')
      .click()
  }

  // Reads the dataset rather than Stimulus params, which JSON-parse values and
  // would mangle a hashid like "12e345" or a memo like "1.50".
  toggle({ target }) {
    const {
      transactionSelectionIdParam: id,
      transactionSelectionMemoParam: memo,
      transactionSelectionDateParam: date,
      transactionSelectionAmountParam: amount,
    } = target.dataset
    const transactions = this.transactionsValue.filter(
      transaction => transaction.id !== id
    )
    if (target.checked) transactions.push({ id, memo, date, amount })
    this.transactionsValue = transactions
    this.refresh()
  }

  remove({ currentTarget }) {
    const id = currentTarget.dataset.transactionSelectionIdParam
    const index = this.transactionsValue.findIndex(
      transaction => transaction.id === id
    )
    this.transactionsValue = this.transactionsValue.filter(
      transaction => transaction.id !== id
    )
    this.refresh()
    const buttons = this.listTarget.querySelectorAll('button')
    ;(
      buttons[Math.min(index, buttons.length - 1)] || this.summaryTarget
    ).focus()
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
    this.summaryTarget.textContent = `${transactions.length} selected · ${USDollar.format(cents / 100)}`
    this.reviewTarget.hidden = transactions.length === 0
    this.listTarget.replaceChildren(
      ...transactions.map(transaction => {
        const row = this.templateTarget.content.cloneNode(true)
        row.querySelector('[data-memo]').textContent = transaction.memo
        row.querySelector('[data-date]').textContent = transaction.date
        row.querySelector('[data-amount]').textContent = USDollar.format(
          transaction.amount
        )
        const remove = row.querySelector('button')
        remove.dataset.transactionSelectionIdParam = transaction.id
        remove.setAttribute('aria-label', `Remove ${transaction.memo}`)
        return row
      })
    )
    this.dispatch('change', { detail: transactions })
  }
}

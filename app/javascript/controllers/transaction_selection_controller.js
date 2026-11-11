import { Controller } from '@hotwired/stimulus'

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

  toggle({ target, params: { id, memo, date, amount } }) {
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

  remove({ params: { id } }) {
    const index = this.transactionsValue.findIndex(
      transaction => transaction.id === String(id)
    )
    this.transactionsValue = this.transactionsValue.filter(
      transaction => transaction.id !== String(id)
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
    this.summaryTarget.textContent = `${transactions.length} selected · ${this.formatAmount(cents / 100)}`
    this.reviewTarget.hidden = transactions.length === 0
    this.listTarget.replaceChildren(
      ...transactions.map(transaction => {
        const row = this.templateTarget.content.cloneNode(true)
        row.querySelector('[data-memo]').textContent = transaction.memo
        row.querySelector('[data-date]').textContent = transaction.date
        row.querySelector('[data-amount]').textContent = this.formatAmount(
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

  formatAmount(amount) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(amount)
  }
}

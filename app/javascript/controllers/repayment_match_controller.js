import { Controller } from '@hotwired/stimulus'

import { USDollar } from '../common/money'

// The picker for marking money in as a repayment: the chosen expenses can be
// submitted once they add up to the money in.
export default class extends Controller {
  static targets = ['inputs', 'submit', 'status']
  static values = { cents: Number }

  selectionChanged({ detail: transactions }) {
    this.inputsTarget.replaceChildren(
      ...transactions.map(transaction => {
        const input = document.createElement('input')
        input.type = 'hidden'
        input.name = 'other_ledger_item_ids[]'
        input.value = transaction.id
        return input
      })
    )

    const left =
      this.centsValue -
      transactions.reduce(
        (sum, transaction) =>
          sum + Math.round(Number(transaction.amount) * 100),
        0
      )
    this.submitTarget.disabled = left !== 0
    this.statusTarget.textContent =
      left === 0
        ? 'Adds up'
        : left > 0
          ? `${USDollar.format(left / 100)} left to match`
          : `${USDollar.format(-left / 100)} too much`
  }
}

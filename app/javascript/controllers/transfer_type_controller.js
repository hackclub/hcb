import { Controller } from '@hotwired/stimulus'

// Drives the transfer form, which asks what kind of transfer it is first and
// then shows that type's questions: a repayment picks the recipient's
// transactions and takes its name and total from them, while a transfer asks
// for them directly.
export default class extends Controller {
  static targets = [
    'types',
    'panel',
    'repaymentRadio',
    'repaymentHint',
    'repaymentName',
    'repaymentAmount',
    'repaidInputs',
    'repaidCard',
    'pickHint',
    'pickButton',
    'repaidEmpty',
    'repaidSummary',
    'repaidMemo',
    'repaidDate',
    'repaidAmount',
    'chooseLabel',
    'changeLabel',
    'repaidError',
  ]
  static values = { transactions: Array }
  static outlets = ['repayment-picker']

  connect() {
    // A name the server filled in from the picked transaction still follows
    // the pick; one passed in from elsewhere is kept.
    const memo = this.transactionsValue
      .map(transaction => transaction.memo)
      .join(', ')
    if (memo && this.repaymentNameTarget.value === this.repaymentName(memo))
      this.autofilledName = this.repaymentNameTarget.value
    this.setRepaid(this.transactionsValue)
    this.select()
  }

  get type() {
    return this.element.querySelector(
      'input[name="disbursement[transfer_type]"]:checked'
    )?.value
  }

  select() {
    // Disabling the inactive panels keeps their fields out of validation and
    // out of the submitted params, since both panels have a name and amount.
    for (const panel of this.panelTargets) {
      const active = panel.dataset.type === (this.type || '')
      panel.hidden = !active
      panel.disabled = !active
    }
  }

  repaymentPicked({ detail }) {
    this.setRepaid(detail)
  }

  setRepaid(transactions) {
    this.transactionsValue = transactions
    this.repaidInputsTarget.replaceChildren(
      ...transactions.map(transaction => {
        const input = document.createElement('input')
        input.type = 'hidden'
        input.name = 'disbursement[repaid_ledger_item_ids][]'
        input.value = transaction.id
        return input
      })
    )
    const selected = transactions.length > 0
    const cents = transactions.reduce(
      (sum, transaction) => sum + Math.round(Number(transaction.amount) * 100),
      0
    )
    this.repaymentAmountTarget.value = selected ? (cents / 100).toFixed(2) : ''

    this.repaidEmptyTarget.hidden = selected || this.pickButtonTarget.disabled
    this.repaidSummaryTarget.hidden = !selected
    this.repaidAmountTarget.hidden = !selected
    this.chooseLabelTarget.hidden = selected
    this.changeLabelTarget.hidden = !selected
    const memo = transactions.map(transaction => transaction.memo).join(', ')
    this.repaidMemoTarget.textContent = memo
    this.repaidDateTarget.textContent =
      transactions.length === 1
        ? transactions[0].date
        : `${transactions.length} transactions`
    this.repaidAmountTarget.textContent = new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(cents / 100)
    if (selected) this.repaidErrorTarget.hidden = true

    this.fillName(selected ? { memo } : null)
  }

  // Names the transfer after what it repays, unless a name was passed in.
  fillName(transaction) {
    const name = this.repaymentNameTarget.value
    if (name && name !== this.autofilledName) return

    this.autofilledName = transaction
      ? this.repaymentName(transaction.memo)
      : ''
    this.repaymentNameTarget.value = this.autofilledName
  }

  // Matches the server's default, which is cut to the field's 60 characters.
  repaymentName(memo) {
    const name = `Repaying ${memo}`
    return name.length > 60 ? `${name.slice(0, 57)}...` : name
  }

  comboboxChanged({ target, detail: { option } }) {
    if (!target.querySelector('input[name="disbursement[event_id]"]')) return

    // A new destination means a new set of transactions to pick from, and
    // there's nothing to pick from until one is chosen.
    this.pickButtonTarget.disabled = !option
    this.pickHintTarget.hidden = !!option
    this.setRepaid([])
    if (this.hasRepaymentPickerOutlet)
      this.repaymentPickerOutlet.setDestination(option?.value)
    this.setRepayable(option?.repayable !== false)
  }

  // Only members of the recipient can see, and so repay, its transactions.
  setRepayable(repayable) {
    this.repaymentRadioTarget.disabled = !repayable
    this.repaymentHintTarget.hidden = repayable
    if (!repayable && this.repaymentRadioTarget.checked) {
      this.repaymentRadioTarget.checked = false
      this.select()
    }
  }

  submit(event) {
    // The radios are hidden behind their labels, so the browser can't point
    // at them when none is picked.
    if (!this.type) {
      event.preventDefault()
      this.typesTarget.scrollIntoView({ behavior: 'smooth', block: 'start' })
      return
    }

    // The pick lives in a hidden field, which the browser won't validate.
    const missing = this.type === 'repayment' && !this.transactionsValue.length
    this.repaidErrorTarget.hidden = !missing
    if (missing) {
      event.preventDefault()
      this.repaidCardTarget.scrollIntoView({
        behavior: 'smooth',
        block: 'center',
      })
    }
  }
}

import { Controller } from '@hotwired/stimulus'

const usd = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
})

// Drives the transfer form, which asks what kind of transfer it is first and
// then shows that type's questions: a repayment picks some of the recipient's
// transactions and takes its name and amount from them, while a transfer asks
// for them directly.
export default class extends Controller {
  static targets = [
    'types',
    'panel',
    'repaymentRadio',
    'repaymentHint',
    'repaymentName',
    'repaymentAmount',
    'repaidList',
    'repaidTemplate',
    'repaidTotal',
    'repaidTotalAmount',
    'pickHint',
    'pickButton',
    'repaidEmpty',
    'chooseLabel',
    'changeLabel',
    'repaidCard',
    'repaidError',
  ]
  static outlets = ['repayment-picker']

  connect() {
    // A name the server filled in from the picked transactions still follows
    // the pick; one passed in from elsewhere is kept.
    const transactions = this.repaidTransactions
    if (
      transactions.length &&
      this.repaymentNameTarget.value === this.repaymentName(transactions)
    )
      this.autofilledName = this.repaymentNameTarget.value
    this.select()
  }

  get type() {
    return this.element.querySelector(
      'input[name="disbursement[transfer_type]"]:checked'
    )?.value
  }

  // The chosen transactions, read back from their rows.
  get repaidTransactions() {
    return [...this.repaidListTarget.children].map(row => ({
      id: row.dataset.id,
      memo: row.dataset.memo,
      date: row.dataset.date,
      amount: row.dataset.amount,
      amountLabel: row.dataset.amountLabel,
    }))
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

  openPicker() {
    if (this.hasRepaymentPickerOutlet)
      this.repaymentPickerOutlet.seed(this.repaidTransactions)
  }

  repaymentPicked({ detail: { transactions } }) {
    this.setRepaid(transactions)
  }

  setRepaid(transactions = []) {
    const any = transactions.length > 0

    this.repaidListTarget.replaceChildren(
      ...transactions.map(transaction => this.repaidRow(transaction))
    )

    const cents = transactions.reduce(
      (sum, t) => sum + Math.round(Number(t.amount) * 100),
      0
    )
    this.repaymentAmountTarget.value = any ? (cents / 100).toFixed(2) : ''
    this.repaidTotalAmountTarget.textContent = any
      ? usd.format(cents / 100)
      : ''

    this.repaidEmptyTarget.hidden = any || this.pickButtonTarget.disabled
    this.repaidListTarget.hidden = !any
    this.repaidTotalTarget.hidden = !any
    this.chooseLabelTarget.hidden = any
    this.changeLabelTarget.hidden = !any
    if (any) this.repaidErrorTarget.hidden = true

    this.fillName(transactions)
  }

  repaidRow({ id, memo, date, amount, amountLabel }) {
    const row =
      this.repaidTemplateTarget.content.firstElementChild.cloneNode(true)
    Object.assign(row.dataset, { id, memo, date, amount, amountLabel })
    const input = row.querySelector('input')
    input.name = 'disbursement[repaid_ledger_item_ids][]'
    input.value = id
    row.querySelector('[data-field="memo"]').textContent = memo
    row.querySelector('[data-field="date"]').textContent = date
    row.querySelector('[data-field="amountLabel"]').textContent = amountLabel
    return row
  }

  // Names the transfer after what it repays, unless a name was passed in.
  fillName(transactions) {
    const name = this.repaymentNameTarget.value
    if (name && name !== this.autofilledName) return

    this.autofilledName = transactions.length
      ? this.repaymentName(transactions)
      : ''
    this.repaymentNameTarget.value = this.autofilledName
  }

  // Matches the server's default, which is cut to the field's 60 characters.
  repaymentName(transactions) {
    if (transactions.length > 1)
      return `Repaying ${transactions.length} transactions`

    const name = `Repaying ${transactions[0].memo}`
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

    // The picks live in hidden fields, which the browser won't validate.
    const missing =
      this.type === 'repayment' && !this.repaidListTarget.children.length
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

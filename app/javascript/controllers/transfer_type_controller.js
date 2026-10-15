import { Controller } from '@hotwired/stimulus'

// Drives the "What kind of transfer is this?" section of the transfer form:
// shows the follow-up question for the chosen type, points the repayment
// picker at the destination organization's transactions, and fills in the
// amount from the transaction being repaid.
export default class extends Controller {
  static targets = [
    'section',
    'hint',
    'panel',
    'repaymentRadio',
    'repaymentHint',
    'amount',
    'repaidInput',
    'repaidCard',
    'repaidEmpty',
    'repaidSummary',
    'repaidMemo',
    'repaidDate',
    'repaidAmount',
    'chooseLabel',
    'changeLabel',
    'repaidError',
    'name',
  ]
  static outlets = ['repayment-picker']

  connect() {
    // Set when the page opens with a transaction already picked.
    this.repaidAmount = this.repaidInputTarget.dataset.amount || null
    // A name the server filled in from the picked transaction still follows
    // the pick until the user edits it.
    const memo = this.repaidMemoTarget.textContent.trim()
    if (memo && this.nameTarget.value === this.repaymentName(memo))
      this.autofilledName = this.nameTarget.value
    this.select()
  }

  get type() {
    return this.element.querySelector(
      'input[name="disbursement[transfer_type]"]:checked'
    )?.value
  }

  select() {
    for (const panel of this.panelTargets) {
      const active = panel.dataset.type === this.type
      panel.hidden = !active
      panel
        .querySelectorAll('select, input')
        .forEach(el => (el.disabled = !active))
    }
    this.lockAmount()
  }

  // A repayment covers the picked transaction in full, so its amount is fixed.
  lockAmount() {
    const locked = this.type === 'repayment' && this.repaidAmount != null
    if (locked) this.amountTarget.value = this.repaidAmount
    this.amountTarget.readOnly = locked
  }

  repaymentPicked({ detail }) {
    this.setRepaid(detail)
  }

  setRepaid(transaction) {
    this.repaidInputTarget.value = transaction?.id || ''
    this.repaidAmount = transaction?.amount ?? null

    this.repaidEmptyTarget.hidden = !!transaction
    this.repaidSummaryTarget.hidden = !transaction
    this.repaidAmountTarget.hidden = !transaction
    this.chooseLabelTarget.hidden = !!transaction
    this.changeLabelTarget.hidden = !transaction
    this.repaidMemoTarget.textContent = transaction?.memo || ''
    this.repaidDateTarget.textContent = transaction?.date || ''
    this.repaidAmountTarget.textContent = transaction?.amountLabel || ''
    if (transaction) this.repaidErrorTarget.hidden = true

    this.fillName(transaction)
    this.lockAmount()
  }

  // Names the transfer after what it repays, unless the user wrote their own.
  fillName(transaction) {
    const name = this.nameTarget.value
    if (name && name !== this.autofilledName) return

    this.autofilledName = transaction
      ? this.repaymentName(transaction.memo)
      : ''
    this.nameTarget.value = this.autofilledName
  }

  // Matches the server's default, which is cut to the field's 60 characters.
  repaymentName(memo) {
    const name = `Repaying ${memo}`
    return name.length > 60 ? `${name.slice(0, 57)}...` : name
  }

  comboboxChanged({ target, detail: { option } }) {
    if (!target.querySelector('input[name="disbursement[event_id]"]')) return

    // A new destination means a new set of transactions to pick from.
    this.setRepaid(null)
    if (this.hasRepaymentPickerOutlet)
      this.repaymentPickerOutlet.setDestination(option?.value)
    this.sectionTarget.disabled = !option
    this.hintTarget.hidden = !!option
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
      this.sectionTarget.scrollIntoView({ behavior: 'smooth', block: 'center' })
      return
    }

    // The pick lives in a hidden field, which the browser won't validate.
    const missing = this.type === 'repayment' && !this.repaidInputTarget.value
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

import { Controller } from '@hotwired/stimulus'

// Drives the "What kind of transfer is this?" section of the transfer form:
// shows the follow-up question for the chosen type, points the repayment
// picker at the destination organization's transactions, and fills in the
// amount from the transaction being repaid.
export default class extends Controller {
  static targets = ['section', 'hint', 'panel', 'repaymentCombobox', 'amount']
  static values = { repayableUrl: String }

  connect() {
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
    if (this.type !== 'repayment') this.amountTarget.readOnly = false
  }

  comboboxChanged({ target, detail: { option } }) {
    if (target === this.repaymentComboboxTarget) {
      target.querySelector('input[role="combobox"]').setCustomValidity('')
      if (!option) return
      this.amountTarget.value = option.amount
      this.amountTarget.readOnly = true
    } else if (target.querySelector('input[name="disbursement[event_id]"]')) {
      // A new destination means a new set of transactions to pick from.
      const url = new URL(this.repayableUrlValue, window.location.origin)
      if (option) url.searchParams.set('destination_event_id', option.value)
      this.repaymentComboboxTarget.dataset.comboboxUrlValue = url.toString()
      this.repaymentCombobox?.clear()
      this.amountTarget.readOnly = false
      this.sectionTarget.disabled = !option
      this.hintTarget.hidden = !!option
    }
  }

  submit(event) {
    const input = this.repaymentComboboxTarget.querySelector(
      'input[role="combobox"]'
    )
    const missing =
      this.type === 'repayment' && !this.repaymentCombobox?.selectedValue
    input.setCustomValidity(
      missing ? "Choose the transaction you're repaying." : ''
    )
    if (missing) {
      event.preventDefault()
      input.reportValidity()
    }
  }

  get repaymentCombobox() {
    return this.application.getControllerForElementAndIdentifier(
      this.repaymentComboboxTarget,
      'combobox'
    )
  }
}

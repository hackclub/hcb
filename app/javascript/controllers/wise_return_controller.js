import { Controller } from '@hotwired/stimulus'

// Reacts to the Wise transfer picked in the return-mapping combobox
// (`combobox:change->wise-return#pick`):
// - prefills the failure reason from `return_reason`, which the search
//   endpoint includes for transfers ops already marked as failed, without
//   clobbering text the admin typed themselves;
// - adds a duplicate-refund warning to the submit button's confirmation when
//   the option says a refund is already mapped onto that transfer.
export default class extends Controller {
  static targets = ['input', 'submit']

  connect() {
    this.baseConfirm = this.submitTarget.dataset.turboConfirm
  }

  pick({ detail: { option } }) {
    this.fillReason(option)
    this.updateConfirm(option)
  }

  fillReason(option) {
    const input = this.inputTarget
    const untouched = input.value === '' || input.value === this.lastFilled

    if (!untouched) return

    const reason = option?.return_reason ?? ''
    input.value = reason
    this.lastFilled = reason
  }

  updateConfirm(option) {
    const warning = option?.duplicate_refund_warning
    this.submitTarget.dataset.turboConfirm = warning
      ? `${this.baseConfirm}\n\n${warning}`
      : this.baseConfirm
  }
}

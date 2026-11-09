import { Controller } from '@hotwired/stimulus'

// Prefills a failure reason input from the Wise transfer picked in a combobox
// (`combobox:change->return-reason#fill`), using the `return_reason` the
// search endpoint includes for transfers ops already marked as failed. Text
// the admin typed themselves is left alone.
export default class extends Controller {
  static targets = ['input']

  fill({ detail: { option } }) {
    const input = this.inputTarget
    const untouched = input.value === '' || input.value === this.lastFilled

    if (!untouched) return

    const reason = option?.return_reason ?? ''
    input.value = reason
    this.lastFilled = reason
  }
}

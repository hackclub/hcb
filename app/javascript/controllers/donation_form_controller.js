import { Controller } from '@hotwired/stimulus'

// Shows how much a donor would need to add to cover the event's revenue fee.
export default class extends Controller {
  static targets = ['amount', 'fee']
  static values = { revenueFee: Number }

  connect() {
    this.update()
  }

  update() {
    if (!this.hasFeeTarget) return

    this.feeTarget.textContent = `Add $${this.additionalAmountToCoverFee} to cover all fees`
  }

  get additionalAmountToCoverFee() {
    const amount = this.amountTarget.value

    if (amount && !isNaN(amount)) {
      return (
        Math.ceil((amount / (1 - this.revenueFeeValue) - amount) * 100) / 100
      ).toFixed(2)
    }
    return '0.00'
  }
}

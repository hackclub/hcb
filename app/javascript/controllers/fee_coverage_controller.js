import { Controller } from '@hotwired/stimulus'

// Shows how much extra a donor would add to cover the fees on their donation.
export default class extends Controller {
  static targets = ['amount', 'label']
  static values = { fee: Number }

  connect() {
    this.update()
  }

  update() {
    if (!this.hasLabelTarget) return

    this.labelTarget.textContent = `Add $${this.extra} to cover all fees`
  }

  get extra() {
    const amount = Number(this.amountTarget.value)
    if (!amount || Number.isNaN(amount)) return '0.00'

    const gross = amount / (1 - this.feeValue)
    return (Math.ceil((gross - amount) * 100) / 100).toFixed(2)
  }
}

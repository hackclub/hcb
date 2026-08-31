import { Controller } from '@hotwired/stimulus'

const currency = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
})

// Shows what the spending balance will be once this allowance is applied.
export default class extends Controller {
  static targets = ['amount', 'preview']
  static values = { balance: Number }

  connect() {
    this.update()
  }

  update() {
    const amount = Number(this.amountTarget.value)
    const sign = this.operation === 'add' ? 1 : -1

    this.previewTarget.textContent = currency.format(
      this.balanceValue + sign * amount
    )
  }

  get operation() {
    return this.element.querySelector('input[name*="[operation]"]:checked')
      ?.value
  }
}

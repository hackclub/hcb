import { Controller } from '@hotwired/stimulus'

// Asks Wise what the recipient's amount comes to in USD, as the currency and
// amount are filled in.
export default class extends Controller {
  static targets = ['currency', 'amount', 'quote']

  connect() {
    this.request = 0
    this.update()
  }

  update() {
    const amount = this.amountTarget.value
    const currency = this.currencyTarget.value

    if (!amount || !currency) {
      this.quoteTarget.textContent =
        'Enter an amount & currency to get an estimate in USD'
      return
    }

    this.quoteTarget.textContent = 'Loading quote from Wise...'

    // Quotes can come back out of order; only the newest one may land.
    const request = ++this.request

    fetch(
      `/wise_transfers/generate_quote?amount=${encodeURIComponent(amount)}&currency=${encodeURIComponent(currency)}`
    )
      .then(response => response.text())
      .then(text => {
        if (request === this.request) {
          this.quoteTarget.textContent = `Approximately ${text} USD`
        }
      })
  }
}

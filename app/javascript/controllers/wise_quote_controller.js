import { Controller } from '@hotwired/stimulus'

// The USD estimate under the Wise transfer form's currency & amount fields.
// Only a change to either field counts, so an amount pre-filled by a re-render
// isn't quoted until it's edited.
export default class extends Controller {
  static targets = ['quote']
  static values = { currency: String }

  amount = ''

  setCurrency({ target: { value } }) {
    this.currencyValue = value
    this.refresh()
  }

  setAmount({ target: { value } }) {
    this.amount = value
    this.refresh()
  }

  get missingInput() {
    return this.amount === '' || this.currencyValue === ''
  }

  refresh() {
    if (this.missingInput) {
      this.quoteTarget.textContent =
        'Enter an amount & currency to get an estimate in USD'
      return
    }

    this.quoteTarget.textContent = 'Loading quote from Wise...'

    fetch(
      '/wise_transfers/generate_quote?amount=' +
        this.amount +
        '&currency=' +
        this.currencyValue
    )
      .then(response => response.text())
      .then(text => {
        // A field may have been emptied while the quote was loading
        if (this.missingInput) return

        this.quoteTarget.textContent = `Approximately ${text} USD`
      })
  }
}

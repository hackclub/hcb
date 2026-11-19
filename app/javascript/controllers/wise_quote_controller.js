import { Controller } from '@hotwired/stimulus'

// The USD estimate under the Wise transfer form's currency & amount fields.
// Only a change to either field triggers a quote, so an amount pre-filled by a
// re-render isn't quoted until one of them is edited.
export default class extends Controller {
  static targets = ['currency', 'amount', 'quote']

  connect() {
    // The view renders the placeholder, so the copy lives in one place
    this.placeholder = this.quoteTarget.textContent
  }

  disconnect() {
    this.abortController?.abort()
  }

  refresh() {
    this.abortController?.abort()

    const currency = this.currencyTarget.value
    const amount = this.amountTarget.value

    if (currency === '' || amount === '') {
      this.quoteTarget.textContent = this.placeholder
      return
    }

    this.quoteTarget.textContent = 'Loading quote from Wise...'

    // Aborting the previous request keeps a slow, stale response from
    // overwriting the quote for the current input
    this.abortController = new AbortController()
    const params = new URLSearchParams({ amount, currency })

    fetch(`/wise_transfers/generate_quote?${params}`, {
      signal: this.abortController.signal,
    })
      .then(response => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        return response.text()
      })
      .then(text => {
        this.quoteTarget.textContent = `Approximately ${text} USD`
      })
      .catch(error => {
        if (error.name === 'AbortError') return

        this.quoteTarget.textContent = "Couldn't load a quote from Wise"
      })
  }
}

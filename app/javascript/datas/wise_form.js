// The quote lookup needs `fetch`, `Number` and a template literal, none of which
// the CSP build will evaluate from a directive, so it all lives here.
export default ({ currency }) => ({
  currency,
  amount: null,
  account_type: null,
  usd_quote: null,
  use_same_email_for_interac: false,
  email: null,

  set_currency(value) {
    this.currency = value
    this.refresh_quote()
  },

  set_amount(value) {
    this.amount = value
    this.refresh_quote()
  },

  refresh_quote() {
    this.usd_quote = NaN

    if (
      this.amount == null ||
      this.amount == '' ||
      this.currency == null ||
      this.currency == ''
    ) {
      return
    }

    fetch(
      '/wise_transfers/generate_quote?amount=' +
        this.amount +
        '&currency=' +
        this.currency
    )
      .then(response => response.text())
      .then(text => {
        this.usd_quote = text
      })
  },

  get quote_text() {
    if (
      this.usd_quote == null ||
      this.currency == null ||
      this.currency == '' ||
      this.amount == null ||
      this.amount == ''
    ) {
      return 'Enter an amount & currency to get an estimate in USD'
    }

    return Number.isNaN(this.usd_quote)
      ? 'Loading quote from Wise...'
      : `Approximately ${this.usd_quote} USD`
  },
})

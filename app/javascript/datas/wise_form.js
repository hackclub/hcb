// The form state read by `currency_specific_details`. The CSP build only takes a
// registered name in `x-data` and won't evaluate assignments from a directive,
// so the state and its setter live here. The USD quote is the `wise-quote`
// Stimulus controller's job.
export default ({ currency }) => ({
  currency,
  account_type: null,
  use_same_email_for_interac: false,
  email: null,

  set_currency(value) {
    this.currency = value
  },
})

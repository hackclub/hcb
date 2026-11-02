// `Intl` is a global, and the CSP build refuses to resolve globals from a
// directive expression, so the formatter lives here rather than in `x-data`.
const formatter = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
})

export default ({ balance_cents }) => ({
  amount: null,
  operation: 'add',
  balance: balance_cents / 100,

  get projected_balance() {
    const amount = Number(this.amount)
    return formatter.format(
      this.balance + (this.operation == 'add' ? amount : -amount)
    )
  },
})

// `Intl` is a global, and the CSP build refuses to resolve globals from a
// directive expression, so the formatter is imported here rather than used in `x-data`.
import { USDollar as formatter } from '../common/money'

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

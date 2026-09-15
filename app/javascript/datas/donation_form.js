// `Math` and `isNaN` are globals, which the CSP build will not resolve from a
// directive, so the fee maths lives here.
export default ({ revenue_fee }) => ({
  amount: null,

  get additionalAmountToCoverFee() {
    if (this.amount && !isNaN(this.amount)) {
      return (
        Math.ceil((this.amount / (1 - revenue_fee) - this.amount) * 100) / 100
      ).toFixed(2)
    }
    return '0.00'
  },
})

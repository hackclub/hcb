import { Controller } from '@hotwired/stimulus'

// Manages the dynamic list of invoice line items: adding & removing rows,
// keeping a running total, and updating the fee preview + "bank transfer only"
// warning based on that total.
export default class extends Controller {
  static targets = [
    'rows',
    'template',
    'row',
    'amount',
    'removeButton',
    'total',
    'feePreview',
    'cardWarning',
  ]

  static values = {
    fee: Number,
    maxCard: Number, // in cents
    index: Number,
  }

  connect() {
    this.recalculate()
    this.updateRemoveButtons()
  }

  add(event) {
    event.preventDefault()

    const html = this.templateTarget.innerHTML.replaceAll(
      'NEW_RECORD',
      this.indexValue
    )
    this.indexValue++

    this.rowsTarget.insertAdjacentHTML('beforeend', html)
    this.updateRemoveButtons()

    // Focus the description field of the row we just added.
    const descriptions = this.rowsTarget.querySelectorAll(
      '[data-invoice-line-items-target="description"]'
    )
    descriptions[descriptions.length - 1]?.focus()
  }

  remove(event) {
    event.preventDefault()

    // Never remove the last remaining row.
    if (this.rowTargets.length <= 1) return

    event.currentTarget
      .closest('[data-invoice-line-items-target="row"]')
      .remove()

    this.updateRemoveButtons()
    this.recalculate()
  }

  updateRemoveButtons() {
    const onlyOne = this.rowTargets.length <= 1
    this.removeButtonTargets.forEach(button => {
      button.classList.toggle('invisible', onlyOne)
      button.disabled = onlyOne
    })
  }

  recalculate() {
    const totalCents = this.amountTargets.reduce((sum, input) => {
      const value = parseFloat(input.value)
      return sum + (isNaN(value) ? 0 : Math.round(value * 100))
    }, 0)

    if (this.hasTotalTarget) {
      this.totalTarget.textContent = this.formatMoney(totalCents)
    }

    this.updateFeePreview(totalCents)
    this.updateCardWarning(totalCents)
  }

  updateFeePreview(totalCents) {
    if (!this.hasFeePreviewTarget) return

    if (this.feeValue > 0 && totalCents > 0) {
      const fee = totalCents * this.feeValue
      const revenue = totalCents - fee
      const percent = (this.feeValue * 100).toFixed(1)
      this.feePreviewTarget.textContent = `${this.formatMoney(
        totalCents
      )} - ${this.formatMoney(fee)} (${percent}% fiscal sponsorship fee) = ${this.formatMoney(
        revenue
      )}`
    } else {
      this.feePreviewTarget.textContent = ''
    }
  }

  updateCardWarning(totalCents) {
    if (!this.hasCardWarningTarget) return
    this.cardWarningTarget.hidden = totalCents < this.maxCardValue
  }

  formatMoney(cents) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format((cents || 0) / 100)
  }
}

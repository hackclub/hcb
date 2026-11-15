import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'items',
    'item',
    'template',
    'total',
    'addButton',
    'removeButton',
    'acknowledgement',
    'count',
    'mismatch',
    'submit',
    'signature',
    'receiptMerchant',
    'receiptDate',
    'receiptItems',
    'receiptTotal',
    'confirmation',
  ]
  static values = { charged: Number }

  connect() {
    this.nextIndex =
      Math.max(
        -1,
        ...this.itemTargets.map(item => Number(item.dataset.index))
      ) + 1
    this.update()
  }

  add() {
    if (this.itemTargets.length >= 50) return
    this.itemsTarget.insertAdjacentHTML(
      'beforeend',
      this.templateTarget.innerHTML.replaceAll('NEW_ITEM', this.nextIndex++)
    )
    this.itemTargets.at(-1).querySelector('input').focus()
    this.update()
  }

  remove(event) {
    if (this.itemTargets.length <= 1) return
    event.target.closest('[data-lost-receipt-target="item"]').remove()
    this.update()
    this.addButtonTarget.focus()
  }

  update() {
    const usd = cents =>
      new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
      }).format(cents / 100)
    const field = name => this.element.querySelector(`[name$="[${name}]"]`)
    this.receiptMerchantTarget.textContent = field('merchant').value
    // The date input's value is YYYY-MM-DD.
    const [year, month, day] = field('date').value.split('-')
    this.receiptDateTarget.textContent = year ? `${month}/${day}/${year}` : ''
    const lines = []
    const cents = this.itemTargets.reduce((total, item) => {
      const quantity = Number(
        item.querySelector('[data-amount="quantity"]').value
      )
      const price = Number(item.querySelector('[data-amount="price"]').value)
      const itemCents = quantity * Math.round(price * 100)
      const line = document.createElement('div')
      line.className = 'paper-receipt__item'
      const description = item.querySelector('input[type="text"]').value
      for (const text of [quantity, description, usd(itemCents || 0)]) {
        line.appendChild(document.createElement('span')).textContent = text
      }
      lines.push(line)
      return total + (Number.isFinite(itemCents) ? itemCents : 0)
    }, 0)
    this.receiptItemsTarget.replaceChildren(...lines)
    this.receiptTotalTarget.textContent = usd(cents)
    this.totalTarget.value = new Intl.NumberFormat('en-US', {
      minimumFractionDigits: 2,
    }).format(cents / 100)
    this.countTarget.textContent = this.itemTargets.length
    // The server checks this too; here it just explains why submit is off.
    const off = this.hasChargedValue ? this.chargedValue - cents : 0
    const money = new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(Math.abs(off) / 100)
    this.mismatchTarget.hidden = off === 0
    this.mismatchTarget.textContent =
      off > 0
        ? `Add ${money} more to match the transaction.`
        : `Remove ${money} to match the transaction.`
    this.submitTarget.disabled = off !== 0
    // Nothing to confirm until the items add up.
    this.confirmationTarget.inert = off !== 0
    this.confirmationTarget.style.opacity = off === 0 ? '' : 0.4
    const signature = this.signatureTarget
    const normalize = text => text.trim().replace(/\s+/g, ' ').toLowerCase()
    signature.setCustomValidity(
      !signature.dataset.name ||
        normalize(signature.value) === normalize(signature.dataset.name)
        ? ''
        : 'Type your name as it appears on your HCB account.'
    )
    this.addButtonTarget.disabled = this.itemTargets.length >= 50
    if (this.hasAcknowledgementTarget) {
      // Same comparison as the server: case, spacing, and punctuation don't matter.
      const normalize = text => text.toLowerCase().replace(/[^a-z0-9]/g, '')
      const field = this.acknowledgementTarget
      field.setCustomValidity(
        normalize(field.value) === normalize(field.dataset.sentence)
          ? ''
          : 'Type the sentence exactly as shown.'
      )
    }
    this.removeButtonTargets.forEach(button => {
      button.disabled = this.itemTargets.length <= 1
    })
  }
}

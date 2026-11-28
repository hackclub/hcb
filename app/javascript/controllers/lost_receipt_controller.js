import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'items',
    'item',
    'template',
    'total',
    'addButton',
    'removeButton',
    'count',
    'mismatch',
    'submit',
    'signature',
    'signatureError',
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
    const cents = this.itemTargets.reduce((total, item) => {
      const quantity = Number(
        item.querySelector('[data-amount="quantity"]').value
      )
      const price = Number(item.querySelector('[data-amount="price"]').value)
      const itemCents = quantity * Math.round(price * 100)
      return total + (Number.isFinite(itemCents) ? itemCents : 0)
    }, 0)
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
    // Nothing to confirm until the items add up.
    this.confirmationTarget.inert = off !== 0
    this.confirmationTarget.style.opacity = off === 0 ? '' : 0.4
    const signature = this.signatureTarget
    const normalize = text => text.trim().replace(/\s+/g, ' ').toLowerCase()
    const typed = normalize(signature.value)
    const name = normalize(signature.dataset.name || '')
    signature.setCustomValidity(
      !name || typed === name
        ? ''
        : 'Type your name as it appears on your HCB account.'
    )
    // Stay quiet while they're still partway through typing it.
    this.signatureErrorTarget.hidden = !name || name.startsWith(typed)
    this.addButtonTarget.disabled = this.itemTargets.length >= 50
    this.removeButtonTargets.forEach(button => {
      button.disabled = this.itemTargets.length <= 1
    })
    // Last, after every check above. Off until the whole form is filled in and valid.
    this.submitTarget.disabled = off !== 0 || !this.element.checkValidity()
  }
}

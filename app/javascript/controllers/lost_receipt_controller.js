import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'items',
    'item',
    'template',
    'total',
    'addButton',
    'removeButton',
    'returnTo',
    'acknowledgement',
    'number',
    'title',
    'count',
  ]

  connect() {
    // In a modal the form loads in a frame, so only the browser knows the page to return to.
    if (this.element.closest('.modal'))
      this.returnToTarget.value = window.location.href
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
    this.itemTargets.forEach((item, index) => {
      this.numberTargets[index].textContent = `#${index + 1}`
      this.titleTargets[index].textContent =
        item.querySelector('[data-description]').value || 'Untitled item'
    })
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

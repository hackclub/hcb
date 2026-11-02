import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'items',
    'item',
    'template',
    'total',
    'addButton',
    'removeButton',
  ]

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
      return total + quantity * Math.round(price * 100)
    }, 0)
    this.totalTarget.value = new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(cents / 100)
    this.addButtonTarget.disabled = this.itemTargets.length >= 50
    this.removeButtonTargets.forEach(button => {
      button.disabled = this.itemTargets.length <= 1
    })
  }
}

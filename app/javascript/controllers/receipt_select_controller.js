import { Controller } from '@hotwired/stimulus'
import fuzzysort from 'fuzzysort'

class Receipt {
  constructor(el) {
    this.filename = el.querySelector('strong').innerText.trim()
    this.id = el.getAttribute('data-receipt-id')
    this.content = el.getAttribute('data-textual-content')
  }

  get searchable() {
    return this.filename + ' ' + this.content
  }
}

export default class extends Controller {
  static targets = ['receipt', 'select', 'confirm', 'noResults', 'search']
  static values = { selected: String }

  select(e) {
    const prevReceiptId = this.selectElement.value + ''

    document
      .querySelectorAll('.receipt--selected')
      .forEach(el => el.classList.remove('receipt--selected'))

    const receiptId = e.currentTarget.getAttribute('data-receipt-id')

    if (receiptId === prevReceiptId) {
      this.confirmTarget.disabled = true
      this.selectElement.value = ''
      return this.#render()
    }

    this.confirmTarget.disabled = false
    this.selectElement.value = receiptId
    e.currentTarget.classList.add('receipt--selected')

    this.#render()
  }

  search() {
    this.#render()
  }

  #render() {
    const query = this.searchTarget.value

    const receipts = this.#filter(query)

    const shown = this.receiptTargets.filter(el =>
      receipts.find(r => r.obj.id === el.getAttribute('data-receipt-id'))
    )
    if (query.length > 0)
      this.searchTarget.parentElement.setAttribute(
        'data-results',
        `${shown.length} result${shown.length === 1 ? '' : 's'}`
      )
    else this.searchTarget.parentElement.removeAttribute('data-results')

    const hidden = this.receiptTargets.filter(el => !shown.includes(el))

    for (let i = 0; i < hidden.length; i++) {
      const el = hidden[i]
      if (el.classList.contains('receipt--selected')) {
        shown.push(hidden.splice(i, 1)[0])
      }
    }

    shown.forEach(el => (el.parentElement.style.display = 'flex'))

    for (let i = 0; i < shown.length; i++) {
      shown[i].parentElement.style.order = i
    }

    hidden.forEach(el => (el.parentElement.style.display = 'none'))

    if (shown.length === 0) {
      this.noResultsTarget.style.display = 'block'
    } else {
      this.noResultsTarget.style.display = 'none'
    }
  }

  #filter(query) {
    return fuzzysort.go(query, this.receipts, {
      keys: ['searchable'],
      all: true,
      threshold: -500000,
    })
  }

  get receipts() {
    return this.receiptTargets.map(el => new Receipt(el))
  }

  get selectElement() {
    return this.selectTarget.children[0]
  }
}

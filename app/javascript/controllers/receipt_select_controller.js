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
  static targets = ['receipt', 'receiptId', 'confirm', 'noResults', 'search']

  select(e) {
    const receipt = e.currentTarget
    const selected = receipt.classList.toggle('receipt--selected')
    const receiptId = receipt.getAttribute('data-receipt-id')

    // The hidden input carrying this receipt's id is submitted only while the
    // receipt is selected.
    this.receiptIdTargets
      .filter(input => input.getAttribute('data-receipt-id') === receiptId)
      .forEach(input => (input.disabled = !selected))

    const count = this.receiptIdTargets.filter(input => !input.disabled).length
    this.confirmTarget.disabled = count === 0
    this.confirmTarget.value =
      count === 0
        ? this.confirmTarget.defaultValue
        : `Add ${count} receipt${count === 1 ? '' : 's'} to transaction`

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

    // Selected receipts stay visible whatever the search says, so the user can
    // see (and undo) what they're about to attach.
    for (let i = hidden.length - 1; i >= 0; i--) {
      if (hidden[i].classList.contains('receipt--selected')) {
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
}

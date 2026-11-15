import { Controller } from '@hotwired/stimulus'

// Swaps between the upload panel and the receipt-bin picker rendered alongside
// it, for the inline (non-modal) variant of the receipt form.
export default class extends Controller {
  static targets = ['form', 'select']

  showSelect(event) {
    event.preventDefault()
    this.swap(true)
  }

  showForm(event) {
    event.preventDefault()
    this.swap(false)
  }

  swap(selecting) {
    this.selectTarget.style.display = selecting ? '' : 'none'
    this.formTarget.style.display = selecting ? 'none' : ''
  }
}

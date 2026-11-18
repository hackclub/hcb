import { Controller } from '@hotwired/stimulus'

// Undoes `expand_receipt` (app/assets/javascripts/ui.js)
export default class extends Controller {
  minimize() {
    const receipt = this.element.closest('.receipt--expanded')
    receipt?.style.setProperty('--receipt-size', '256px')
    receipt?.classList.remove('receipt--expanded')
    this.element
      .closest('.modal--popover')
      ?.classList.remove('modal--popover--receipt-expanded')
  }
}

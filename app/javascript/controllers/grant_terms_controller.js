import { Controller } from '@hotwired/stimulus'

// Progressive enhancement for the dual-option grant invitation. The shared
// terms are `required` inputs enforced by the browser; the Card Issuing Terms
// can't be (they'd also block the reimbursement submit), so they gate the
// virtual card button here instead. Without JS the button stays usable.
export default class extends Controller {
  static targets = ['cardTerm', 'cardSubmitButton']

  connect() {
    this.update()
  }

  update() {
    const agreed = this.cardTermTargets.every(cb => cb.checked)
    this.cardSubmitButtonTargets.forEach(btn => {
      btn.disabled = !agreed
    })
  }
}

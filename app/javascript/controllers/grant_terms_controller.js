import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['term', 'cardTerm', 'submitButton', 'cardSubmitButton']

  termTargetConnected() {
    this.update()
  }

  cardTermTargetConnected() {
    this.update()
  }

  update() {
    const sharedChecked = this.termTargets.every(cb => cb.checked)
    const cardTermsChecked = this.cardTermTargets.length === 0 || this.cardTermTargets.every(cb => cb.checked)

    // Reimbursement (and generic) buttons only need shared terms
    this.submitButtonTargets.forEach(btn => {
      btn.disabled = !sharedChecked
    })

    // Virtual card buttons need shared terms AND card-specific terms
    this.cardSubmitButtonTargets.forEach(btn => {
      btn.disabled = !(sharedChecked && cardTermsChecked)
    })
  }
}

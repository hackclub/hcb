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
    const allChecked = this.termTargets.every(cb => cb.checked)
    const allCardChecked = allChecked && this.cardTermTargets.every(cb => cb.checked)
    this.submitButtonTargets.forEach(btn => {
      btn.disabled = !allChecked
    })
    this.cardSubmitButtonTargets.forEach(btn => {
      btn.disabled = !allCardChecked
    })
  }
}

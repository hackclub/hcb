import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['term', 'submitButton']

  termTargetConnected() {
    this.update()
  }

  update() {
    const allChecked = this.termTargets.every(cb => cb.checked)
    this.submitButtonTargets.forEach(btn => {
      btn.disabled = !allChecked
    })
  }
}

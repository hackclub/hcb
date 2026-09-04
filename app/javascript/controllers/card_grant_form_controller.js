import { Controller } from '@hotwired/stimulus'

// Shows card-only grant options only while the virtual card acceptance method is enabled.
export default class extends Controller {
  static targets = ['stripeCard', 'cardOption']

  connect() {
    this.toggle()
  }

  toggle() {
    const enabled = this.stripeCardTarget.checked
    this.cardOptionTargets.forEach(el => {
      el.hidden = !enabled
    })
  }
}

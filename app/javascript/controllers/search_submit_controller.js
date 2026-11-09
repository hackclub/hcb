import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input', 'button']

  connect() {
    this.appliedQuery = this.inputTarget.defaultValue.trim()
    this.toggle()
  }

  toggle() {
    const pending = this.inputTarget.value.trim() !== this.appliedQuery
    this.buttonTarget.classList.toggle('display-none', !pending)
  }

  // Turbo only marks forms busy on submit, so mirror it for link visits like clearing
  markBusy() {
    this.inputTarget.form.setAttribute('aria-busy', 'true')
  }

  unmarkBusy() {
    this.inputTarget.form.removeAttribute('aria-busy')
  }
}

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
}

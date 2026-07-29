import { Controller } from '@hotwired/stimulus'

// Reveals a submit button in the search bar once the query differs from the
// one that's currently applied, so it's obvious that a search is pending.
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

import { Controller } from '@hotwired/stimulus'

// Stamps a value into a field elsewhere on the page — typically the hidden input
// of a shared modal, so it knows which record it was opened for.
export default class extends Controller {
  static values = { input: String, content: String }

  set() {
    const input = document.getElementById(this.inputValue)
    if (input) input.value = this.contentValue
  }
}

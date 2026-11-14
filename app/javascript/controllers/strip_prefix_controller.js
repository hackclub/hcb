import { Controller } from '@hotwired/stimulus'

// Pasting a full URL into an id field should leave just the id behind,
// without any query string or fragment.
export default class extends Controller {
  static values = { prefix: String }

  paste(event) {
    const pasted = event.clipboardData.getData('Text')
    if (!pasted.startsWith(this.prefixValue)) return

    event.preventDefault()
    event.target.value = pasted
      .substring(this.prefixValue.length)
      .split(/[?#]/)[0]
  }
}

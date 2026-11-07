import { Controller } from '@hotwired/stimulus'

// Clears a field and submits, disabling the button so it can't be double-fired
// while the request is in flight.
export default class extends Controller {
  static targets = ['field', 'button']

  clear() {
    this.fieldTarget.value = ''
    this.buttonTarget.disabled = true
    this.element.requestSubmit()
  }
}

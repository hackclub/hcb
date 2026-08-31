import { Controller } from '@hotwired/stimulus'

// Blocks submission with a specific message when the field holds a value it
// shouldn't — e.g. a cosigner email that's the applicant's own.
export default class extends Controller {
  static values = { message: String, equals: String }

  check() {
    this.element.setCustomValidity(
      this.element.value === this.equalsValue ? this.messageValue : ''
    )
  }
}

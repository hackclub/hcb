import { Controller } from '@hotwired/stimulus'

// Copies a file input's selection onto another input, so a styled picker and the
// field the form actually submits stay in sync.
export default class extends Controller {
  static values = { to: String }

  mirror() {
    const target = document.getElementById(this.toValue)
    if (target) target.files = this.element.files
  }
}

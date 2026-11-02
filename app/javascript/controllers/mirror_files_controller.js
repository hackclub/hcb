import { Controller } from '@hotwired/stimulus'

// Copies a file input's in org settings (bg image/logo)
export default class extends Controller {
  static values = { to: String }

  mirror({ target } = {}) {
    const source = target instanceof HTMLInputElement ? target : this.element
    const destination = document.getElementById(this.toValue)
    if (destination && source.files) destination.files = source.files
  }
}

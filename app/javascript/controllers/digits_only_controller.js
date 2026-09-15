import { Controller } from '@hotwired/stimulus'

// Keeps a field to digits, trimmed to a fixed length.
export default class extends Controller {
  static values = { length: { type: Number, default: 4 } }

  mask() {
    this.element.value = this.element.value
      .replace(/[^0-9]/g, '')
      .substring(0, this.lengthValue)
  }
}

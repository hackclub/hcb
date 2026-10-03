import { Controller } from '@hotwired/stimulus'

// Stops a preview from being upscaled past its natural width once it loads.
export default class extends Controller {
  static values = { minHeight: { type: String, default: '300px' } }

  connect() {
    // A cached image can already be decoded by the time we connect, in which
    // case its load event has been and gone.
    if (this.element.complete && this.element.naturalWidth) this.fit()
  }

  fit() {
    this.element.style.maxWidth = `${this.element.naturalWidth}px`
    this.element.style.minHeight = this.minHeightValue
  }
}

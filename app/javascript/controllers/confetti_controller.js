import { Controller } from '@hotwired/stimulus'
import JSConfetti from 'js-confetti'

const jsConfetti = new JSConfetti()

export default class extends Controller {
  static values = {
    emojis: String,
    auto: { type: Boolean, default: false },
  }

  connect() {
    // Let the page settle before firing, so the confetti isn't half-offscreen.
    if (this.autoValue) this.timeout = setTimeout(() => this.party(), 100)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  party() {
    if (this.emojisValue) {
      jsConfetti.addConfetti({ emojis: this.emojisValue.split(',') })
    } else {
      jsConfetti.addConfetti()
    }
  }
}

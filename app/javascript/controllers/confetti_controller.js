import { Controller } from '@hotwired/stimulus'
import JSConfetti from 'js-confetti'

let jsConfetti

function confetti() {
  jsConfetti ??= new JSConfetti()
  if (!jsConfetti.canvas.isConnected) document.body.append(jsConfetti.canvas)
  return jsConfetti
}

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
      confetti().addConfetti({ emojis: this.emojisValue.split(',') })
    } else {
      confetti().addConfetti()
    }
  }
}

import { Controller } from '@hotwired/stimulus'

// Turbo frames can't use `action="advance"` here — it would push the frame's own
// src — so the filtered URL is pushed by hand when the frame renders.
export default class extends Controller {
  static values = { url: String }

  connect() {
    window.history.pushState(null, '', this.urlValue)
  }
}

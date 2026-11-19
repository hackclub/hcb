import { Controller } from '@hotwired/stimulus'

// Turbo frames can't use `action="advance"` here — it would push the frame's own
// src — so the filtered URL is pushed by hand when the frame renders.
export default class extends Controller {
  static values = { url: String }

  connect() {
    // The frame also renders on page load, where its URL is already the page's.
    // Keeping Turbo's state lets Turbo restore the page on Back and Forward.
    if (new URL(this.urlValue, location.href).href !== location.href)
      history.pushState(history.state, '', this.urlValue)
  }
}

import { Controller } from '@hotwired/stimulus'
import loadTurnstile from '../common/turnstile'

// Renders a Cloudflare Turnstile widget into this element. The widget writes
// its token into a `cf-turnstile-response` field, so the element has to live
// inside the form that gets submitted.
export default class extends Controller {
  static values = { sitekey: String, action: String }

  async connect() {
    const turnstile = await loadTurnstile()

    // Turbo can disconnect us while the script is still in flight.
    if (!this.element.isConnected) return

    this.widgetId = turnstile.render(this.element, {
      sitekey: this.sitekeyValue,
      action: this.actionValue,
    })
  }

  disconnect() {
    if (this.widgetId === undefined) return

    window.turnstile?.remove(this.widgetId)
    this.widgetId = undefined
  }
}

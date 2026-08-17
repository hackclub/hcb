import { Controller } from '@hotwired/stimulus'
import loadTurnstile from '../common/turnstile'

// Renders a Cloudflare Turnstile widget into this element. The widget writes
// its token into a `cf-turnstile-response` field, so the element has to live
// inside the form that gets submitted.
//
// Until the challenge is solved there is no token, so the form's submit controls
// are held disabled — a submit before then would only bounce off the
// server-side check. This is a UX guard, not a security control: the server is
// the real gate, so we fail *open* (re-enable) whenever the widget can't run
// (script blocked, hard error, teardown). That keeps a Cloudflare hiccup from
// locking people out of the shared login form; the money path (`#sms`) still
// fails closed server-side.
//
// When the form already carries a `form-disable` controller — it owns the
// button for its own reasons, e.g. requiring a radio choice — we defer to it:
// we only announce readiness via a `turnstile:change` event and let it fold
// that into its own decision. Otherwise we toggle the submit controls directly.
export default class extends Controller {
  static values = { sitekey: String, action: String }

  async connect() {
    // Held disabled until the widget produces a token.
    this.setReady(false)

    let turnstile
    try {
      turnstile = await loadTurnstile()
    } catch {
      // Script blocked or failed to load — don't strand the form.
      this.setReady(true)
      return
    }

    // Turbo can disconnect us while the script is still in flight.
    if (!this.element.isConnected) return

    this.widgetId = turnstile.render(this.element, {
      sitekey: this.sitekeyValue,
      action: this.actionValue,
      callback: () => this.setReady(true),
      'expired-callback': () => this.setReady(false),
      'error-callback': () => this.setReady(true),
    })
  }

  disconnect() {
    // A torn-down widget (e.g. Turbo navigation) must not leave the button dead.
    this.setReady(true)

    if (this.widgetId === undefined) return

    window.turnstile?.remove(this.widgetId)
    this.widgetId = undefined
  }

  setReady(ready) {
    const form = this.element.closest('form')
    if (!form) return

    // Let a `form-disable` controller own the button when one is present.
    form.dispatchEvent(
      new CustomEvent('turnstile:change', { detail: { ready }, bubbles: false })
    )

    if (
      form.matches('[data-controller~="form-disable"]') ||
      form.querySelector('[data-controller~="form-disable"]')
    ) {
      return
    }

    this.submitControls(form).forEach(el => {
      el.disabled = !ready
    })
  }

  // Submit buttons/inputs owned by this form, including any associated from
  // outside it via a `form=` attribute (e.g. the sticky footer button).
  submitControls(form) {
    return Array.from(form.elements).filter(
      el =>
        (el.tagName === 'BUTTON' && (el.type === 'submit' || el.type === '')) ||
        (el.tagName === 'INPUT' && el.type === 'submit')
    )
  }
}

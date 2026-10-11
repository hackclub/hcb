/*
  Renders a Cloudflare Turnstile widget inside a form, parks the solved token
  in a hidden field, and holds the form's submit button until there is one.

  The hidden field is named `cf-turnstile-response`, which is where
  `TurnstileProtection` reads the token from on the server. Cloudflare can
  inject that field itself, but we turn that off and write it by hand so the
  token can't go stale without the button going back to disabled alongside it.
*/

import { Controller } from '@hotwired/stimulus'
import loadTurnstile from '../common/turnstile'

export default class extends Controller {
  static targets = ['widget', 'token', 'submit', 'error']
  static values = {
    sitekey: String,
    action: String,
  }

  connect() {
    this.#setToken(null)

    // We render explicitly rather than letting Cloudflare's script scan for
    // `.cf-turnstile` elements: this form lives in a Turbo frame that's swapped
    // in after load, which the automatic scan never sees.
    loadTurnstile()
      .then(turnstile => {
        if (!this.element.isConnected) return

        this.widgetId = turnstile.render(this.widgetTarget, {
          sitekey: this.sitekeyValue,
          action: this.actionValue,
          'response-field': false,
          callback: token => this.#setToken(token),
          'expired-callback': () => this.#setToken(null),
          'error-callback': () => this.#setToken(null),
        })
      })
      .catch(() => {
        // The server rejects a tokenless submission anyway, so say why the
        // button is stuck rather than letting someone fill the form for
        // nothing.
        if (this.hasErrorTarget) this.errorTarget.hidden = false
      })
  }

  disconnect() {
    if (this.widgetId === undefined) return

    // Throws if the widget's element has already been torn out from under us,
    // which a Turbo frame swap can do.
    try {
      window.turnstile?.remove(this.widgetId)
    } catch {
      // The widget is gone either way.
    }
    this.widgetId = undefined
  }

  #setToken(token) {
    if (this.hasTokenTarget) this.tokenTarget.value = token || ''

    this.submitTargets.forEach(submit => {
      submit.disabled = !token
    })
  }
}

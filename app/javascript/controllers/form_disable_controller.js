import { Controller } from '@hotwired/stimulus'

// Holds the submit button(s) disabled until the form is ready to send: a radio
// option is chosen (when the form offers them) and — when a Turnstile widget
// gates the form — the challenge has been solved. The Turnstile controller
// announces its state via `turnstile:change`; wire it with
// `data-action="turnstile:change->form-disable#turnstileChanged"`.
export default class extends Controller {
  static targets = ['radioButton', 'submitButton']

  initialize() {
    // Start not-ready only when a Turnstile widget actually gates this form, so
    // forms without one (and their `turnstile:change` wiring) behave as before.
    this.turnstileReady = !this.element.querySelector(
      '[data-controller~="turnstile"]'
    )
    this.run()
  }

  run() {
    const radioReady =
      this.radioButtonTargets.length === 0 ||
      this.radioButtonTargets.some(input => input.checked)

    const disabled = !(radioReady && this.turnstileReady)

    this.submitButtonTargets.forEach(button => {
      button.disabled = disabled
    })
  }

  turnstileChanged(event) {
    this.turnstileReady = event.detail.ready
    this.run()
  }
}

/*
  Guards the "Send an HCB transfer" form (DisbursementsController#new) against
  submitting a blank source/destination organization.

  The org pickers are async comboboxes (hotwire_combobox) whose value is a hidden
  field committed only after a deliberate selection. Wrong-org auto-commits are
  prevented at the source (see strict_hw_combobox.js). What remains is a timing
  race: a user can hit submit during an in-flight search, before any value has
  committed, and send a blank organization. We block that here with a friendly,
  inline message and focus the offending picker.

  This is a UX guard only — the server remains authoritative for presence,
  authorization, and balance (see DisbursementsController#create), so a submit
  with JS disabled or via the API is still validated.
*/

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['error']

  connect() {
    // Turbo caches the DOM; a restored page must not show a stale error.
    this.reset()
  }

  onSubmit(event) {
    const source = this.#hiddenField('source_event_id')
    const destination = this.#hiddenField('event_id')

    if (this.#isBlank(source)) {
      this.#block(
        event,
        'source_event_id',
        'You must select an organization to send from.'
      )
    } else if (this.#isBlank(destination)) {
      this.#block(
        event,
        'event_id',
        'You must select an organization to send to.'
      )
    }
  }

  // Clears a stale error whenever the form is edited.
  reset() {
    this.#clearError()
  }

  #hiddenField(name) {
    return this.element.querySelector(`input[name="disbursement[${name}]"]`)
  }

  #visibleField(name) {
    return this.element.querySelector(`#disbursement_${name}`)
  }

  #isBlank(hiddenField) {
    return !hiddenField || hiddenField.value.trim() === ''
  }

  #block(event, name, message) {
    // Never block silently. If the error region is missing (removed/renamed/
    // outside this controller), don't preventDefault into a dead-end with no
    // message — let the submit through and rely on the authoritative server
    // validation (DisbursementsController#create redirects with a flash error).
    if (!this.hasErrorTarget) {
      console.error(
        'disbursement-form: missing error target; deferring blank-org validation to the server'
      )
      return
    }

    event.preventDefault()

    // Reveal the alert region *before* writing its text so the text mutation
    // happens inside a visible role="alert" region and is announced reliably.
    this.errorTarget.hidden = false
    this.errorTarget.textContent = message

    const visible = this.#visibleField(name)
    if (visible) {
      // Associate the message with the field so a screen reader reads it when
      // focus lands here — reliable regardless of live-region timing. (We leave
      // aria-invalid to the combobox controller, which owns it.)
      if (this.errorTarget.id) {
        visible.setAttribute('aria-describedby', this.errorTarget.id)
      }
      visible.focus()
    }
  }

  #clearError() {
    if (this.hasErrorTarget && !this.errorTarget.hidden) {
      this.errorTarget.hidden = true
      this.errorTarget.textContent = ''

      // Drop the association we added in #block (only from fields pointing at
      // our error, so we never clobber another describedby).
      if (this.errorTarget.id) {
        this.element
          .querySelectorAll(`[aria-describedby="${this.errorTarget.id}"]`)
          .forEach(el => el.removeAttribute('aria-describedby'))
      }
    }
  }
}

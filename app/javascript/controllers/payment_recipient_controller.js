import { Controller } from '@hotwired/stimulus'
import { useState } from 'reactionview'

// The saved-recipient picker shared by the ACH, wire, and check transfer forms.
//
// The recipient lives in the form's herb states: `selected_payment_recipient_id`
// (submitted as `payment_recipient_id`), `selected_editing`, and a
// `selected_<key>` state for each detail the form shows read-only (the `shown`
// value, e.g. `bank_name` → `selected_bank_name`). While a recipient is picked
// and not being edited, the form hides and disables its editable fields
// (`editable` targets), so the server fills them in from the recipient.
//
// The editable fields are plain form fields, not bound to states, so they keep
// Rails' error styling. When they come back into view they start over from
// their rendered values, and editing a recipient fills them in from it.
const FIELD_NAMES = { email: 'recipient_email' }
const SKIPPED_KEYS = ['id', 'name', 'masked_account_number']

export default class extends Controller {
  static targets = ['name', 'email', 'editable', 'debug']
  static values = { recipient: Object, scope: String, shown: Array }

  connect() {
    useState(this)
    this.recipient = this.recipientValue
  }

  select({ params: { recipient } }) {
    this.recipient = recipient
    this.nameTarget.value = recipient.name
    if (this.hasEmailTarget) this.emailTarget.value = recipient.email

    const shown = Object.fromEntries(
      this.shownValue.map(key => [`selected_${key}`, recipient[key] ?? ''])
    )
    this.state.set({
      selected_payment_recipient_id: recipient.id,
      selected_editing: false,
      ...shown,
    })
    this.showDebug()
  }

  // Typing a different name forgets the picked recipient.
  clear() {
    if (!this.state.get('selected_payment_recipient_id')) return

    const reappearing = !this.state.get('selected_editing')

    this.recipient = {}
    this.state.set({ selected_payment_recipient_id: '' })
    if (reappearing) this.resetEditable()
    this.showDebug()
  }

  edit({ params: { focus } }) {
    this.state.set({ selected_editing: true })
    this.resetEditable()

    Object.entries(this.recipient).forEach(([key, value]) => {
      if (SKIPPED_KEYS.includes(key)) return

      const name = `${this.scopeValue}[${FIELD_NAMES[key] ?? key}]`
      const field = this.element.elements.namedItem(name)
      if (field?.tagName) this.fill(field, value ?? '')
    })

    if (focus) document.getElementById(focus)?.focus()
  }

  resetEditable() {
    this.editableTargets.forEach(group => {
      group.querySelectorAll('input, select, textarea').forEach(field => {
        if (field.type === 'hidden') return

        if (field.tagName === 'SELECT') {
          const option =
            [...field.options].find(option => option.defaultSelected) ??
            field.options[0]
          this.fill(field, option?.value ?? '')
        } else {
          this.fill(field, field.defaultValue)
        }
      })
    })
  }

  // Sets a field as if it had been typed in, so the herb states and
  // validations that listen to it follow.
  fill(field, value) {
    if (field.value === value) return

    field.value = value
    field.dispatchEvent(
      new Event(field.tagName === 'SELECT' ? 'change' : 'input', {
        bubbles: true,
      })
    )
  }

  showDebug() {
    if (!this.hasDebugTarget) return

    this.debugTarget.textContent =
      'Debug info:\n\n' + JSON.stringify(this.recipient, null, 2)
  }
}

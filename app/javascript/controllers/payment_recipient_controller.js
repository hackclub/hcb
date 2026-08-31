import { Controller } from '@hotwired/stimulus'

// Picking a saved recipient collapses the payment fields into a read-only
// summary; the pencil reopens them, prefilled. Shared by the ACH, wire and check
// transfer forms, which differ only in which fields they fill.
//
// Visibility is left to `conditional-fields` on the same form: this controller
// publishes `recipient` ("present" or "") and `editing` into that state.
export default class extends Controller {
  static targets = ['name', 'id', 'debug']
  static values = {
    recipient: Object,
    editing: Boolean,
    // DOM id -> attribute on the recipient
    fields: Object,
    focus: String,
    // Wires also drive the country-specific fields from the recipient.
    country: Boolean,
  }

  connect() {
    this.render()
  }

  select(event) {
    this.recipientValue = JSON.parse(event.currentTarget.dataset.recipient)
    this.editingValue = false

    if (this.hasNameTarget) this.nameTarget.value = this.recipientValue.name
    if (this.countryValue) this.publishCountry()

    this.render()
  }

  clear() {
    this.recipientValue = {}
    this.render()
  }

  edit() {
    this.editingValue = true
    this.render()

    // The fields only exist once conditional-fields has cloned their template in.
    Object.entries(this.fieldsValue).forEach(([id, key]) => {
      const field = document.getElementById(id)
      if (field) field.value = this.recipientValue[key] ?? ''
    })
    if (this.countryValue) this.publishCountry()

    document.getElementById(this.focusValue)?.focus()
  }

  render() {
    const { present } = this

    if (this.hasIdTarget)
      this.idTarget.value = present ? this.recipientValue.id : ''
    if (this.hasDebugTarget) {
      this.debugTarget.textContent = `Debug info:\n\n${JSON.stringify(this.recipientValue, null, 2)}`
    }

    this.element
      .querySelectorAll('[data-payment-recipient-summary]')
      .forEach(field => {
        field.value =
          this.recipientValue[field.dataset.paymentRecipientSummary] ?? ''
      })

    this.publish('recipient', present ? 'present' : '')
    this.publish('editing', this.editingValue)
  }

  publishCountry() {
    this.publish('country', this.recipientValue.recipient_country || '')
  }

  publish(key, value) {
    this.dispatch('set', { detail: { key, value } })
  }

  get present() {
    return Boolean(this.recipientValue && this.recipientValue.id)
  }
}

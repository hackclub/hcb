import { Controller } from '@hotwired/stimulus'

// Warns (but never blocks) when the email typed into the new-recipient form
// already belongs to an existing recipient on this organization. Duplicates
// are allowed on purpose — the same person can be a recipient more than once
// when they're paid under different legal entities (e.g. a personal account
// and a business) — so this is a heads-up, not a hard stop.
export default class extends Controller {
  static targets = ['email', 'warning', 'names']
  // existing: [{ email, name }] for the org's non-archived recipients.
  static values = { existing: Array }

  connect() {
    this.check()
  }

  check() {
    if (!this.hasEmailTarget || !this.hasWarningTarget) return

    const email = this.emailTarget.value.trim().toLowerCase()
    const matches = email
      ? this.existingValue.filter(payee => payee.email === email)
      : []

    if (matches.length === 0) {
      this.warningTarget.hidden = true
      return
    }

    if (this.hasNamesTarget) {
      this.namesTarget.textContent = this.formatNames(
        matches.map(payee => payee.name)
      )
    }
    this.warningTarget.hidden = false
  }

  formatNames(names) {
    if (names.length === 1) return names[0]
    if (names.length === 2) return `${names[0]} and ${names[1]}`
    return `${names.slice(0, -1).join(', ')}, and ${names[names.length - 1]}`
  }
}

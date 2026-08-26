import { Controller } from '@hotwired/stimulus'
import { debounce } from 'lodash/function'

// Warns when the email being entered for a new recipient/contractor already
// belongs to an existing recipient in this organization. It never blocks
// submission — duplicates are allowed (e.g. a separate legal entity) — it just
// surfaces the existing recipient so people don't create one by accident.
export default class extends Controller {
  static values = { url: String }
  static targets = ['email', 'warning', 'names']

  initialize() {
    this.check = debounce(this._check, 400)
  }

  connect() {
    // Re-check a pre-filled email (e.g. after the form was re-rendered).
    if (this.hasEmailTarget && this.emailTarget.value.trim()) {
      this._check()
    }
  }

  hideWarning() {
    if (this.hasWarningTarget) this.warningTarget.hidden = true
    if (this.hasNamesTarget) this.namesTarget.textContent = ''
  }

  async _check() {
    if (!this.hasEmailTarget) return

    const email = this.emailTarget.value.trim()

    // Wait until there's a syntactically valid email before hitting the server.
    if (!email || !this.emailTarget.checkValidity()) {
      this.hideWarning()
      return
    }

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set('email', email)

    let data
    try {
      const response = await fetch(url, {
        headers: { Accept: 'application/json' },
      })

      if (!response.ok) {
        this.hideWarning()
        return
      }

      data = await response.json()
    } catch {
      this.hideWarning()
      return
    }

    if (data.duplicate && data.recipients && data.recipients.length) {
      if (this.hasNamesTarget) {
        this.namesTarget.textContent = data.recipients
          .map(recipient => recipient.name)
          .join(', ')
      }
      if (this.hasWarningTarget) this.warningTarget.hidden = false
    } else {
      this.hideWarning()
    }
  }
}

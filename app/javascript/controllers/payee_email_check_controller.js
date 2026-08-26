import { Controller } from '@hotwired/stimulus'
import { debounce } from 'lodash/function'

// Warns, without blocking, when the email typed into the "new recipient" form
// already belongs to another recipient on this organization. Duplicate emails
// are allowed on purpose (the same person can be paid as separate legal
// entities), so this is an informational nudge, not a hard stop.
export default class extends Controller {
  static values = { url: String }
  static targets = ['warning', 'names']

  initialize() {
    this.check = debounce(this._check, 400)
  }

  hideWarning() {
    this.warningTarget.hidden = true
  }

  async _check(e) {
    const email = e.target.value.trim()

    if (!email) {
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

    if (data.duplicate) {
      this.namesTarget.textContent = this.formatNames(data.names)
      this.warningTarget.hidden = false
    } else {
      this.hideWarning()
    }
  }

  formatNames(names) {
    if (!names || names.length === 0) return 'Another recipient'
    if (names.length === 1) return names[0]
    if (names.length === 2) return `${names[0]} and ${names[1]}`
    return `${names.slice(0, -1).join(', ')}, and ${names[names.length - 1]}`
  }
}

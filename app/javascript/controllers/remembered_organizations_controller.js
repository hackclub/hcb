import { Controller } from '@hotwired/stimulus'

const STORAGE_KEY = 'hcb:remembered-organizations'

// Remembers which transparent organizations the user manages so that, once
// their session expires, we can nudge them to sign back in when they land on
// one of those organizations in transparency mode.
export default class extends Controller {
  static targets = ['signIn', 'hint']
  static values = { eventIds: Array, clear: Boolean, currentEvent: String }

  connect() {
    if (this.clearValue) this.remove()
    if (this.hasEventIdsValue) this.write(this.eventIdsValue)

    if (
      this.hasSignInTarget &&
      this.currentEventValue &&
      this.read().includes(this.currentEventValue)
    ) {
      this.signInTarget.classList.add('user-menu-trigger--nudge')
      this.hintTarget.classList.remove('hidden')
    }
  }

  // localStorage throws in some private browsing modes; this is best-effort.
  read() {
    try {
      const ids = JSON.parse(localStorage.getItem(STORAGE_KEY))
      return Array.isArray(ids) ? ids : []
    } catch {
      return []
    }
  }

  write(ids) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(ids))
    } catch {} // eslint-disable-line no-empty
  }

  remove() {
    try {
      localStorage.removeItem(STORAGE_KEY)
    } catch {} // eslint-disable-line no-empty
  }
}

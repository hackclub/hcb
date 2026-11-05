import { Controller } from '@hotwired/stimulus'

const STORAGE_KEY = 'hcb:remembered-organizations'
const DISMISSED_KEY = 'hcb:signed-out-notice-dismissed'

// Remembers which transparent organizations the user manages so that, once
// their session expires, we can nudge them to sign back in when they land on
// one of those organizations in transparency mode.
export default class extends Controller {
  static targets = ['signIn', 'hint', 'publicNotice', 'signedOutNotice']
  static values = { eventIds: Array, clear: Boolean, currentEvent: String }

  connect() {
    if (this.clearValue) this.remove()
    if (this.hasEventIdsValue) this.write(this.eventIdsValue)

    if (
      !this.currentEventValue ||
      !this.read().includes(this.currentEventValue)
    )
      return

    if (this.hasSignInTarget) {
      this.signInTarget.classList.add('user-menu-trigger--nudge')
      this.hintTarget.classList.remove('hidden')
    }

    if (this.hasSignedOutNoticeTarget && !this.dismissed()) {
      this.showSignedOutNotice(true)
    }
  }

  // Hides the signed-out banner for the rest of this tab's session
  dismiss() {
    try {
      sessionStorage.setItem(DISMISSED_KEY, 'true')
    } catch {} // eslint-disable-line no-empty
    this.showSignedOutNotice(false)
  }

  showSignedOutNotice(show) {
    this.signedOutNoticeTarget.classList.toggle('hidden', !show)
    this.signedOutNoticeTarget.classList.toggle('flex', show)
    this.publicNoticeTarget.classList.toggle('hidden', show)
  }

  dismissed() {
    try {
      return sessionStorage.getItem(DISMISSED_KEY) === 'true'
    } catch {
      return false
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

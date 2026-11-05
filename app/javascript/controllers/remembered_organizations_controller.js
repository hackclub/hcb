import { Controller } from '@hotwired/stimulus'

const STORAGE_KEY = 'hcb:remembered-organizations'
const DISMISSED_KEY = 'hcb:signed-out-notice-dismissed'

// Web storage throws in some private browsing modes; this is best-effort.
const safely = (fn, fallback) => {
  try {
    return fn()
  } catch {
    return fallback
  }
}

// Remembers which transparent organizations the user manages so that, once
// their session expires, we can nudge them to sign back in when they land on
// one of those organizations in transparency mode.
//
// The list intentionally outlives the session. It only holds public
// organizations, and is cleared on explicit sign out or replaced when someone
// else signs in on this browser.
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
    safely(() => sessionStorage.setItem(DISMISSED_KEY, 'true'))
    this.showSignedOutNotice(false)
  }

  showSignedOutNotice(show) {
    this.signedOutNoticeTarget.classList.toggle('hidden', !show)
    this.signedOutNoticeTarget.classList.toggle('flex', show)
    this.publicNoticeTarget.classList.toggle('hidden', show)
  }

  dismissed() {
    return safely(() => sessionStorage.getItem(DISMISSED_KEY) === 'true', false)
  }

  read() {
    const ids = safely(() => JSON.parse(localStorage.getItem(STORAGE_KEY)))
    return Array.isArray(ids) ? ids : []
  }

  write(ids) {
    safely(() => localStorage.setItem(STORAGE_KEY, JSON.stringify(ids)))
  }

  remove() {
    safely(() => localStorage.removeItem(STORAGE_KEY))
  }
}

/* global $ */

import { Controller } from '@hotwired/stimulus'

const STORAGE_KEY = 'hcb:remembered-organizations'
const DISMISSED_KEY = 'hcb:signed-out-modal-dismissed'

// Web storage throws in some private browsing modes; this is best-effort.
const safely = (fn, fallback) => {
  try {
    return fn()
  } catch {
    return fallback
  }
}

// Remembers which transparent organizations the user manages so that, once
// their session expires, we can prompt them to sign back in when they land on
// one of those organizations in transparency mode.
//
// The list intentionally outlives the session. It only holds public
// organizations, and is cleared on explicit sign out or replaced when someone
// else signs in on this browser.
export default class extends Controller {
  static targets = ['signIn', 'hint', 'modal']
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

    if (this.hasModalTarget && !this.dismissed() && !$.modal.isActive()) {
      this.openModal()
    }
  }

  // However the modal is closed, don't open it again for the rest of this
  // tab's session; the sign-in nudge stays as a reminder.
  openModal() {
    $(this.modalTarget)
      .one($.modal.CLOSE, () =>
        safely(() => sessionStorage.setItem(DISMISSED_KEY, 'true'))
      )
      .modal({ fadeDuration: 200, closeExisting: false })
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

import { Controller } from '@hotwired/stimulus'

const WARNING = 'You have an unsaved comment. Leave and discard your draft?'

export default class extends Controller {
  static targets = ['content']
  static values = { savedContent: String }

  connect() {
    this.changed()
  }

  changed() {
    this.submitting = false
    this.discarding = false
  }

  get unsaved() {
    return (
      !this.submitting &&
      !this.discarding &&
      this.contentTarget.value.length >= 25 &&
      this.contentTarget.value !== this.savedContentValue
    )
  }

  beforeUnload(event) {
    if (!this.unsaved) return

    event.preventDefault()
    event.returnValue = ''
  }

  leave(event) {
    if (event.defaultPrevented || !this.unsaved) return

    // Modal and frame events only discard drafts inside that container.
    if (
      event.type !== 'turbo:before-visit' &&
      !event.target.contains(this.element)
    )
      return

    // Keep this synchronous so closing a modal can be cancelled before it is cleared.
    // eslint-disable-next-line no-alert
    if (window.confirm(WARNING)) {
      this.discarding = true
    } else if (event.type === 'turbo:before-frame-render') {
      // Finish the frame request without replacing the draft or leaving it busy.
      event.detail.render = () => {}
    } else {
      event.preventDefault()
    }
  }

  submitStart() {
    this.submitting = true
  }

  submitEnd(event) {
    if (!event.detail.success) this.submitting = false
  }
}

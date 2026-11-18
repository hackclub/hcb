import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  // https://turbo.hotwired.dev/reference/events#turbo%3Asubmit-end
  submitEnd(event) {
    if (event.detail.success) {
      this.close()
    }
  }

  close() {
    this.element.closest('dialog').close()
  }
}

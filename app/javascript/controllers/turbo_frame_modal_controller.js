import { Controller } from '@hotwired/stimulus'
import { closeModal } from '../modal'

export default class extends Controller {
  // https://turbo.hotwired.dev/reference/events#turbo%3Asubmit-end
  submitEnd(event) {
    if (event.detail.success) {
      this.close()
    }
  }

  close() {
    closeModal(this.element.closest('dialog'))
  }
}

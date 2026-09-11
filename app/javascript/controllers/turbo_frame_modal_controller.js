import { Controller } from '@hotwired/stimulus'
import $ from 'jquery'

export default class extends Controller {
  static values = { reloadOnSuccess: Boolean }

  // https://turbo.hotwired.dev/reference/events#turbo%3Asubmit-end
  submitEnd(event) {
    if (event.detail.success) {
      $.modal.close()
      if (this.reloadOnSuccessValue)
        window.Turbo.visit(window.location.href, { action: 'replace' })
    }
  }
}

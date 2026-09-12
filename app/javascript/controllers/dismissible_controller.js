import { Controller } from '@hotwired/stimulus'

// A callout the visitor can dismiss for good. Hidden server-side so it never
// flashes before we've checked whether it was already dismissed.
export default class extends Controller {
  static targets = ['link']
  static values = { key: String }

  connect() {
    if (localStorage.getItem(this.keyValue) !== 'true') {
      this.element.style.display = 'block'
    }
  }

  follow() {
    this.linkTarget.click()
  }

  dismiss() {
    localStorage.setItem(this.keyValue, 'true')
    this.element.remove()
  }
}

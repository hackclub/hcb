import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { advancePath: String }
  static targets = ['button']

  completed() {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = false
    } else {
      window.location.href = this.advancePathValue
    }
  }

  void() {
    window.location.href = '/'
  }
}

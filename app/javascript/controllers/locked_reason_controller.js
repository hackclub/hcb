import $ from 'jquery'
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['reason', 'checkbox']
  static values = { originallyLocked: Boolean }

  connect() {
    this.toggle()
    $(this.reasonTarget).hide()
  }

  toggle() {
    if (this.checkboxTarget.checked && !this.originallyLockedValue) {
      $(this.reasonTarget).show()
    } else {
      $(this.reasonTarget).hide()
    }
  }
}

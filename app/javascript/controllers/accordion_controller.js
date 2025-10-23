import $ from 'jquery'
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets() {
    return ['checkbox', 'content']
  }

  connect() {
    if (!this.checkboxTarget.checked) {
      $(this.contentTarget).hide()
    }
  }

  toggle() {
    if (this.checkboxTarget.checked) {
      $(this.contentTarget).slideDown()
    } else {
      $(this.contentTarget).slideUp()
    }
  }
}

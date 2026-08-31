import { Controller } from '@hotwired/stimulus'

// Opens a URL in a new tab from an element that isn't a link.
export default class extends Controller {
  static values = { url: String }

  open(event) {
    event.preventDefault()
    window.open(this.urlValue, '_blank')
  }
}

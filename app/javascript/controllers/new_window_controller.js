import { Controller } from '@hotwired/stimulus'

// Opens a URL in a new tab from an element that isn't a link. Set
// `prevent-value="false"` where the element has its own behaviour to keep — a
// Turbo link that should also open a second tab, say.
export default class extends Controller {
  static values = {
    url: String,
    prevent: { type: Boolean, default: true },
  }

  open(event) {
    if (this.preventValue) event.preventDefault()
    window.open(this.urlValue, '_blank')
  }
}

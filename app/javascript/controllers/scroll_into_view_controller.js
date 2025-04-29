import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    alignment: { type: String, default: 'nearest' },
  }

  connect() {
    this.element.scrollIntoView({
      inline: this.alignmentValue,
      block: this.alignmentValue,
    })
  }
}

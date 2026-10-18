import { Controller } from '@hotwired/stimulus'
import { debounce } from 'lodash/function'

export default class extends Controller {
  static values = { url: String }
  static targets = ['frame']

  initialize() {
    this.update = debounce(this._update, 400)
  }

  _update(e) {
    if (!this.hasFrameTarget) return

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set('amount', e.target.value)
    this.frameTarget.src = url
  }
}

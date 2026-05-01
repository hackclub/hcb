import { Controller } from '@hotwired/stimulus'
import { debounce } from 'lodash/function'

export default class extends Controller {
  static values = { url: String }
  static targets = ['warning', 'link']

  initialize() {
    this.check = debounce(this._check, 400)
  }

  async _check(e) {
    const name = e.target.value.trim()

    if (!name) {
      this.warningTarget.hidden = true
      return
    }

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set('name', name)

    let data
    try {
      data = await fetch(url, { headers: { Accept: 'application/json' } }).then(r => r.json())
    } catch {
      return
    }

    if (data.duplicate) {
      this.linkTarget.textContent = data.org_name
      this.linkTarget.href = data.org_url
      this.warningTarget.hidden = false
    } else {
      this.warningTarget.hidden = true
    }
  }
}

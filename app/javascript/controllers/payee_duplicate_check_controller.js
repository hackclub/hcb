import { Controller } from '@hotwired/stimulus'
import { debounce } from 'lodash/function'

export default class extends Controller {
  static values = { url: String, destination: String }
  static targets = ['warning', 'list']

  initialize() {
    this.check = debounce(this._check, 400)
  }

  hideWarning() {
    this.warningTarget.hidden = true
    this.listTarget.replaceChildren()
  }

  async _check(e) {
    const email = e.target.value.trim()

    if (!email) {
      this.hideWarning()
      return
    }

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set('email', email)
    url.searchParams.set('destination', this.destinationValue)

    let data
    try {
      const response = await fetch(url, {
        headers: { Accept: 'application/json' },
      })

      if (!response.ok) {
        this.hideWarning()
        return
      }

      data = await response.json()
    } catch {
      this.hideWarning()
      return
    }

    if (data.duplicate && data.payees?.length) {
      this.render(data.payees)
      this.warningTarget.hidden = false
    } else {
      this.hideWarning()
    }
  }

  render(payees) {
    const nodes = []
    payees.forEach((payee, i) => {
      if (i > 0)
        nodes.push(
          document.createTextNode(i === payees.length - 1 ? ' and ' : ', ')
        )
      const link = document.createElement('a')
      link.href = payee.select_url
      link.className = 'underline font-medium'
      link.textContent = payee.managed ? `${payee.name} (managed)` : payee.name
      nodes.push(link)
    })
    this.listTarget.replaceChildren(...nodes)
  }
}

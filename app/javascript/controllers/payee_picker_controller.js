import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'addingPanel',
    'defaultPanel',
    'summary',
    'nameInput',
    'emailInput',
  ]

  showAdding() {
    this.addingPanelTarget.hidden = false
    this.defaultPanelTarget.hidden = true
    if (this.hasSummaryTarget) this.summaryTarget.hidden = true
  }

  async showAddingFromSearch(event) {
    const query = (event.params.query || '').trim()
    const checkEmailFormatUrl = event.params.url

    if (query) {
      const isEmail =
        checkEmailFormatUrl &&
        (await this.#isEmailFormat(checkEmailFormatUrl, query))

      if (isEmail) {
        this.emailInputTarget.value = query
      } else {
        this.nameInputTarget.value = query
      }
    }
    this.showAdding()
  }

  hideAdding() {
    this.addingPanelTarget.hidden = true
    this.defaultPanelTarget.hidden = false
    if (this.hasSummaryTarget) this.summaryTarget.hidden = false
  }

  async #isEmailFormat(checkEmailFormatUrl, query) {
    try {
      const url = new URL(checkEmailFormatUrl, window.location.origin)
      url.searchParams.set('email', query)

      const response = await fetch(url, {
        headers: { Accept: 'application/json' },
      })
      if (!response.ok) return false

      const { valid } = await response.json()
      return valid
    } catch {
      return false
    }
  }
}

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
    if (event.params.query)
      this[
        event.params.isEmail ? 'emailInputTarget' : 'nameInputTarget'
      ].value = event.params.query
    this.showAdding()
  }

  hideAdding() {
    this.addingPanelTarget.hidden = true
    this.defaultPanelTarget.hidden = false
    if (this.hasSummaryTarget) this.summaryTarget.hidden = false
  }
}

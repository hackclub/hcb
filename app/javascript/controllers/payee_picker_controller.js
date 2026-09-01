import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'addingPanel',
    'defaultPanel',
    'searchHidden',
    'summary',
    'nameInput',
    'emailInput',
  ]

  showAdding() {
    this.addingPanelTarget.hidden = false
    this.defaultPanelTarget.hidden = true
    if (this.hasSummaryTarget) this.summaryTarget.hidden = true
  }

  showAddingFromSearch(event) {
    const query = (event.params.query || '').trim()
    if (query) {
      if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(query)) {
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
}

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'addingPanel',
    'defaultPanel',
    'summary',
    'divider',
    'nameInput',
    'emailInput',
  ]

  showAdding() {
    this.addingPanelTarget.hidden = false
    this.defaultPanelTarget.hidden = true
    if (this.hasSummaryTarget) this.summaryTarget.hidden = true
    if (this.hasDividerTarget) this.dividerTarget.classList.add('hidden')
  }

  async showAddingFromSearch(event) {
    if (event.params.query) {
      const filled = event.params.isEmail
        ? 'emailInputTarget'
        : 'nameInputTarget'
      const other = event.params.isEmail
        ? 'nameInputTarget'
        : 'emailInputTarget'
      this[filled].value = event.params.query
      this[other].value = ''
    }
    this.showAdding()
  }

  hideAdding() {
    this.addingPanelTarget.hidden = true
    this.defaultPanelTarget.hidden = false
    if (this.hasSummaryTarget) this.summaryTarget.hidden = false
    if (this.hasDividerTarget) this.dividerTarget.classList.remove('hidden')
  }
}

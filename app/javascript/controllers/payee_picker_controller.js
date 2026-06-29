import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['addingPanel', 'defaultPanel', 'searchHidden', 'summary']

  showAdding() {
    this.addingPanelTarget.hidden = false
    this.defaultPanelTarget.hidden = true
    if (this.hasSummaryTarget) this.summaryTarget.hidden = true
  }

  hideAdding() {
    this.addingPanelTarget.hidden = true
    this.defaultPanelTarget.hidden = false
    if (this.hasSummaryTarget) this.summaryTarget.hidden = false
  }

  search(event) {
    const searching = event.target.value.length > 0
    this.searchHiddenTargets.forEach(el => {
      el.hidden = searching
    })
  }
}

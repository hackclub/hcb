import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['addingPanel', 'defaultPanel', 'summary']

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
}

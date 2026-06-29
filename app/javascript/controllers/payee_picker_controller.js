import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['addingPanel', 'defaultPanel', 'searchHidden']

  showAdding() {
    this.addingPanelTarget.hidden = false
    this.defaultPanelTarget.hidden = true
  }

  hideAdding() {
    this.addingPanelTarget.hidden = true
    this.defaultPanelTarget.hidden = false
  }

  search(event) {
    const searching = event.target.value.length > 0
    this.searchHiddenTargets.forEach(el => {
      el.hidden = searching
    })
  }
}

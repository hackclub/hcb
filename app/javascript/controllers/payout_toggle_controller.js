import { Controller } from '@hotwired/stimulus'

// Toggles the "Payout settings" section (and its sidebar step) based on
// whether a manual payout is selected in the payment details.
export default class extends Controller {
  static targets = ['section']

  connect() {
    this.update()
  }

  toggle() {
    this.update()
  }

  update() {
    const manual = this.manualSelected

    if (this.hasSectionTarget) this.sectionTarget.hidden = !manual

    const step = document.querySelector('[data-payout-step]')
    if (step) step.hidden = !manual

    this.renumber()
  }

  get manualSelected() {
    const checked = this.element.querySelector(
      'input[name="manual"]:checked'
    )
    return checked?.value === 'true'
  }

  renumber() {
    const tabs = document.querySelectorAll(
      '#table-of-contents .step-tab:not([hidden])'
    )
    tabs.forEach((tab, index) => {
      const number = tab.querySelector('.step-tab__number')
      if (number) number.textContent = index + 1
    })
  }
}

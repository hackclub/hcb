import { Controller } from '@hotwired/stimulus'

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

    this.sectionTargets.forEach(el => (el.hidden = !manual))

    document
      .querySelectorAll('[data-payout-step]')
      .forEach(step => (step.hidden = !manual))

    this.renumber()
  }

  get manualSelected() {
    // Read the payment form's manual field specifically — the payee picker
    // renders its own input[name="manual"] (always "false") earlier in the DOM.
    const field = this.element.querySelector(
      '[data-manual-payee-target="manualField"]'
    )
    return field?.value === 'true'
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

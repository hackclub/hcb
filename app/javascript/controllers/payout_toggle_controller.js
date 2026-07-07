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
    const field = this.element.querySelector('input[name="manual"]')
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

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    showCondition: String,
  }

  static targets = ['field', 'select']

  connect() {
    this.toggle()
  }

  toggle() {
    const selectedValue = this.selectTarget.value

    this.fieldTarget.hidden = selectedValue !== this.showConditionValue
  }
}

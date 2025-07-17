import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    condition: String,
  }

  static targets = ['field', 'select']

  connect() {
    this.toggle()
  }

  toggle() {
    const selectedValue = this.selectTarget.value

    if (selectedValue === this.conditionValue) {
      this.fieldTarget.style.display = 'none'
    } else {
      this.fieldTarget.style.display = 'block'
    }
  }
}

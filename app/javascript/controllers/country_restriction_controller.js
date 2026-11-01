import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['select', 'warning', 'name']
  static values = { disallowed: Array }

  connect() {
    this.update()
  }

  update() {
    const disallowed = this.disallowedValue.includes(this.selectTarget.value)

    this.warningTarget.hidden = !disallowed
    this.nameTarget.textContent = this.selectTarget.selectedOptions[0].label
    this.selectTarget.setCustomValidity(
      disallowed ? 'HCB is not supported in this country' : ''
    )
  }
}

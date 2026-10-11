import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['recurring', 'fixed', 'unitField']
  static values = { fixedUnit: { type: String, default: 'contract' } }

  connect() {
    this.savedUnit =
      this.unitFieldTarget.value === this.fixedUnitValue
        ? 'hour'
        : this.unitFieldTarget.value || 'hour'
    this.update()
  }

  update() {
    const fixed = this.isFixed

    this.recurringTarget.hidden = fixed
    this.fixedTarget.hidden = !fixed

    if (fixed) {
      if (this.unitFieldTarget.value !== this.fixedUnitValue) {
        this.savedUnit = this.unitFieldTarget.value
      }
      this.unitFieldTarget.value = this.fixedUnitValue
    } else if (this.unitFieldTarget.value === this.fixedUnitValue) {
      this.unitFieldTarget.value = this.savedUnit || 'hour'
    }
  }

  get isFixed() {
    return (
      this.element.querySelector('input[name="rate_type"]:checked')?.value ===
      'fixed'
    )
  }
}

import { Controller } from '@hotwired/stimulus'

// Keeps a unit label in step with the number typed beside it.
export default class extends Controller {
  static targets = ['input', 'label']
  static values = { singular: String, plural: String }

  connect() {
    this.update()
  }

  update() {
    this.labelTarget.textContent =
      Number(this.inputTarget.value) === 1
        ? this.singularValue
        : this.pluralValue
  }
}

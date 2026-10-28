import { Controller } from '@hotwired/stimulus'

// Turbo reads `data-turbo-confirm` off the submitter when it is clicked, so the
// message can name an amount the visitor has only just typed — as long as it is
// rewritten before the click finishes.
export default class extends Controller {
  static values = { template: String, field: String }

  update() {
    const field = this.element.form?.elements[this.fieldValue]
    if (!field) return

    this.element.dataset.turboConfirm = this.templateValue.replace(
      '%{amount}',
      field.value
    )
  }
}

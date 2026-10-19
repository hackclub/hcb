import { Controller } from '@hotwired/stimulus'

// Pressing Enter in the template name field would otherwise submit the card
// grant form with its default button ("Send grant").
export default class extends Controller {
  static targets = ['saveButton']

  save(event) {
    event.preventDefault()
    this.saveButtonTarget.form.requestSubmit(this.saveButtonTarget)
  }
}

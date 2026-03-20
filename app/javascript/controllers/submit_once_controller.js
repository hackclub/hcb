import { Controller } from '@hotwired/stimulus'

// Prevents double-submission of forms by disabling the submit button after the
// first click. Attach with data-controller="submit-once" on the <form> element.
export default class extends Controller {
  submit(e) {
    if (e.submitter) {
      e.submitter.disabled = true
    }
  }
}

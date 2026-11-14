import { Controller } from '@hotwired/stimulus'

// A parent or legal guardian cosigns a minor's application, so the cosigner's
// email can't be the applicant's own (`applicant`).
export default class extends Controller {
  static values = { applicant: String }

  check() {
    this.element.setCustomValidity(
      this.element.value === this.applicantValue
        ? 'You cannot use your own email'
        : ''
    )
  }
}

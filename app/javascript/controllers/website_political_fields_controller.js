import { Controller } from '@hotwired/stimulus'

// Shared by the two application project-info forms: each "Yes/No" select makes
// its follow-up field required only while it's set to "Yes".
export default class extends Controller {
  static targets = ['websiteField', 'politicalField']

  toggleWebsite({ target }) {
    this.websiteFieldTarget.required = target.value === 'true'
    if (target.value === 'false') this.websiteFieldTarget.value = ''
  }

  togglePolitical({ target }) {
    this.politicalFieldTarget.required = target.value === 'true'
  }
}

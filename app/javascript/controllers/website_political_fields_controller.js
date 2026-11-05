import { Controller } from '@hotwired/stimulus'

// Shared by the two application project-info forms: each "Yes/No" select shows
// its follow-up field, and makes it required, only while it's set to "Yes".
export default class extends Controller {
  static targets = ['website', 'websiteField', 'political', 'politicalField']

  toggleWebsite({ target: { value } }) {
    this.websiteTarget.hidden = value !== 'true'
    this.websiteFieldTarget.required = value === 'true'
    if (value === 'false') this.websiteFieldTarget.value = ''
  }

  togglePolitical({ target: { value } }) {
    this.politicalTarget.hidden = value !== 'true'
    this.politicalFieldTarget.required = value === 'true'
  }
}

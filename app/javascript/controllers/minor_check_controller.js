import { Controller } from '@hotwired/stimulus'

// Eighteen years in milliseconds — the cut-off the application form uses to
// decide whether a cosigner is needed.
const EIGHTEEN_YEARS = 568_025_136_000

// Recomputes "is this applicant under 18?" from the date-of-birth selects.
export default class extends Controller {
  check() {
    const spoken = Array.from(this.element.children)
      .map(select => select.selectedOptions[0].label)
      .join(' ')

    this.dispatch('set', {
      detail: {
        key: 'minor',
        value: new Date() - new Date(spoken) < EIGHTEEN_YEARS,
      },
    })
  }
}

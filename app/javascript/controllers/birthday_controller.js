import { Controller } from '@hotwired/stimulus'

// Eighteen years, in milliseconds.
const EIGHTEEN_YEARS = 568_025_136_000

// Reads a Rails `date_select` (three <select>s in a wrapper) and announces
// whether the chosen date is less than eighteen years ago, so the form around it
// can ask for a cosigner.
export default class extends Controller {
  change() {
    const parts = [...this.element.children].map(
      select => select.selectedOptions[0].label
    )
    const minor = Date.now() - new Date(parts.join(' ')) < EIGHTEEN_YEARS

    this.dispatch('change', { detail: { minor } })
  }
}

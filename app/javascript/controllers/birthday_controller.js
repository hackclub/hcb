import { Controller } from '@hotwired/stimulus'
import { useState } from 'reactionview'

// Eighteen years, in milliseconds.
const EIGHTEEN_YEARS = 568_025_136_000

// Reads a Rails `date_select` (three <select>s in a wrapper) and sets the
// `minor` state of the herb view around it to whether the chosen date is less
// than eighteen years ago, so the form can ask for a cosigner. A date that
// can't be parsed yet (a part still on its prompt) doesn't count as a minor's.
export default class extends Controller {
  connect() {
    useState(this)
  }

  change() {
    const parts = [...this.element.children].map(
      select => select.selectedOptions[0].label
    )
    const minor = Date.now() - new Date(parts.join(' ')) < EIGHTEEN_YEARS

    this.state.set({ minor })
  }
}

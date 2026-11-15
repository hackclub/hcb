import { Controller } from '@hotwired/stimulus'
import { useState } from 'reactionview'

const MINIMUM_WORDS = 50

// The project questions of an application (`event/applications/_project_info_card`
// and the admin's `_edit_project_info_card`). The herb view shows, hides and
// requires the fields; this does the parts a state can't:
//
// - answering "No" to having a website empties the website field, so saving
//   clears it rather than keeping the old one
// - `committed_funding` follows whether the committed amount is above zero,
//   which asks where the funding comes from
// - an adult-run project's description (the `description` target) needs at
//   least 50 words, counted into `word_count_hint`
export default class extends Controller {
  static targets = ['website', 'description']

  connect() {
    useState(this)

    if (this.hasDescriptionTarget) this.count()
  }

  selected_has_websiteChanged(value) {
    if (value === 'false' && this.hasWebsiteTarget)
      this.websiteTarget.value = ''
  }

  commit({ target }) {
    this.state.set({ committed_funding: Number(target.value) > 0 })
  }

  count() {
    const words = this.descriptionTarget.value.match(/\S+/g)?.length || 0
    const remaining = MINIMUM_WORDS - words

    this.state.set({
      word_count_hint:
        remaining > 0
          ? `${remaining} more word${remaining > 1 ? 's' : ''} required`
          : '',
    })
    this.descriptionTarget.setCustomValidity(
      remaining > 0 ? `Please enter at least ${MINIMUM_WORDS} words` : ''
    )
  }
}

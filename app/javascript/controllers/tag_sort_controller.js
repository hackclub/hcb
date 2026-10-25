import { Controller } from '@hotwired/stimulus'
import csrf from '../common/csrf'

export default class extends Controller {
  static values = {
    event: String,
  }

  async sort({ detail: { oldIndex, newIndex, dragEvent } }) {
    if (oldIndex == newIndex) return

    const { tagId } = dragEvent.originalSource.dataset

    await fetch(`/${this.eventValue}/tags/${tagId}/set_index`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrf(),
      },
      body: JSON.stringify({ index: newIndex }),
    })
  }
}

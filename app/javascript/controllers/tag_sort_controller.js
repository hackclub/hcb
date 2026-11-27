import { Controller } from '@hotwired/stimulus'
import csrf from '../common/csrf'

// Persists a drag-and-drop reorder from the `sortable` controller. Each
// draggable carries its own set_index URL, so the list can change underneath
// us (a tag deleted via Turbo Stream) without stale indexes.
export default class extends Controller {
  async sort({ detail: { oldIndex, newIndex, dragEvent } }) {
    if (oldIndex == newIndex) return

    await fetch(dragEvent.originalSource.dataset.setIndexUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrf(),
      },
      body: JSON.stringify({ index: newIndex }),
    })
  }
}

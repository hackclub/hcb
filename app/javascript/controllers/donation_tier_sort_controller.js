import { Controller } from '@hotwired/stimulus'
import csrf from '../common/csrf'

export default class extends Controller {
  static values = {
    positions: Array,
  }

  async sort({ detail: { oldIndex, newIndex } }) {
    if (oldIndex == newIndex) return

    const copy = this.positionsValue

    const id = copy[oldIndex]

    copy.splice(oldIndex, 1)
    copy.splice(newIndex, 0, id)

    this.positionsValue = copy

    await fetch(`/${id}/donation/tiers/set_index`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrf(),
      },
      body: JSON.stringify({ id, index: newIndex }),
    })
  }
}

import { Controller } from '@hotwired/stimulus'
import csrf from '../common/csrf'

export default class extends Controller {
  static values = {
    event: String,
  }

  async sort({ detail: { oldIndex, newIndex, dragEvent } }) {
    if (oldIndex == newIndex) return

    const { tag } = dragEvent.originalSource.dataset

    await fetch(`/${this.eventValue}/tags/${tag}/set_index`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrf(),
      },
      body: JSON.stringify({ index: newIndex }),
    })

    // Every other tag list on the page is static markup, so mirror the new order into them
    const order = [...this.element.querySelectorAll('[data-tag]')].map(
      row => row.dataset.tag
    )
    document
      .querySelectorAll('[data-controller~="tag-sort"]')
      .forEach(list =>
        list.prepend(
          ...order.map(id => list.querySelector(`[data-tag="${id}"]`))
        )
      )
  }
}

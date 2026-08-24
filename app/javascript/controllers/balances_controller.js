import { Controller } from '@hotwired/stimulus'

// Coalesces the balance frames rendered by the sub-organization tree (one per
// row, potentially hundreds on a single page) into as few requests as
// possible: every frame that connects within the same tick — the initial
// render, or a batch of rows inserted by expanding a branch — is fetched in
// one call to `async_balances`, instead of each row triggering its own
// turbo-frame request.
// Must match EventsController::ASYNC_BALANCES_LIMIT — batches larger than
// that get truncated server-side, so anything queued beyond one chunk is
// split into its own request rather than silently dropped.
const CHUNK_SIZE = 300

export default class extends Controller {
  static targets = ['frame']
  static values = { url: String }

  initialize() {
    this.pendingIds = new Set()
  }

  frameTargetConnected(frame) {
    const cached = localStorage.getItem(`cached_frame:${frame.id}`)

    if (cached) {
      frame.innerHTML = cached
      return
    }

    this.pendingIds.add(frame.dataset.eventPublicId)
    this.#scheduleFlush()
  }

  #scheduleFlush() {
    if (this.flushScheduled) return

    this.flushScheduled = true
    queueMicrotask(() => this.#flush())
  }

  async #flush() {
    this.flushScheduled = false

    const ids = [...this.pendingIds]
    this.pendingIds.clear()
    if (ids.length === 0) return

    const chunks = []
    for (let i = 0; i < ids.length; i += CHUNK_SIZE) {
      chunks.push(ids.slice(i, i + CHUNK_SIZE))
    }

    await Promise.all(chunks.map(chunk => this.#fetchChunk(chunk)))
  }

  async #fetchChunk(ids) {
    const url = new URL(this.urlValue, window.location.href)
    for (const id of ids) url.searchParams.append('ids[]', id)

    let response
    try {
      response = await fetch(url, {
        headers: { Accept: 'text/vnd.turbo-stream.html' },
      })
    } catch {
      return
    }
    if (!response.ok) return

    window.Turbo.renderStreamMessage(await response.text())

    for (const id of ids) {
      const frame = document.getElementById(`event_balance_${id}`)
      if (frame) localStorage.setItem(`cached_frame:${frame.id}`, frame.innerHTML)
    }
  }
}

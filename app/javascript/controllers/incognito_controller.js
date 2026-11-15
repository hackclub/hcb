import { Controller } from '@hotwired/stimulus'

// Reveals its own element when the page is being viewed in a private/incognito
// window.
//
// Browsers deliberately make this hard to detect, so every check below is a
// heuristic tuned to avoid false positives: a regular window should never trip
// them, but some private windows will slip through (notably Firefox 115+, which
// no longer leaks a usable signal). Detection is best-effort and purely
// informational — it must never break the page.
export default class extends Controller {
  async connect() {
    if (await this.#isPrivate()) {
      this.element.hidden = false
    }
  }

  async #isPrivate() {
    try {
      switch (this.#engine()) {
        case 'webkit':
          return await this.#webkitIsPrivate()
        case 'chromium':
          return await this.#chromiumIsPrivate()
        case 'firefox':
          // Firefox didn't expose service workers in private windows until 115.
          return navigator.serviceWorker === undefined
      }
    } catch {
      // Fall through: if we can't tell, assume they're in a regular window.
    }

    return false
  }

  #engine() {
    const ua = navigator.userAgent

    // Every iOS browser is Safari under the hood, so treat them all as WebKit.
    if (/iPad|iPhone|iPod/.test(ua)) return 'webkit'
    // Chromium's user agent also claims Safari, hence the exclusions.
    if (/Safari/.test(ua) && !/Chrome|Chromium|Edg|OPR/.test(ua))
      return 'webkit'
    if (/Firefox/.test(ua)) return 'firefox'
    if (/Chrome|Chromium|Edg|OPR/.test(ua)) return 'chromium'

    return 'unknown'
  }

  // Chromium hands regular profiles a storage quota proportional to free disk
  // space, but caps incognito profiles at a small fraction of that.
  async #chromiumIsPrivate() {
    const { quota } = await navigator.storage.estimate()
    if (!quota) return false

    const heapLimit = performance.memory?.jsHeapSizeLimit ?? 1024 * 1024 * 1024
    return quota < heapLimit * 2
  }

  // Safari's private windows back IndexedDB with an ephemeral store that can't
  // hold Blobs.
  #webkitIsPrivate() {
    return new Promise(resolve => {
      const name = `incognito-probe-${Math.random().toString(36).slice(2)}`
      const request = indexedDB.open(name, 1)
      let isPrivate = false

      request.onerror = () => resolve(false)
      request.onblocked = () => resolve(false)
      request.onupgradeneeded = event => {
        try {
          event.target.result
            .createObjectStore('probe', { autoIncrement: true })
            .put(new Blob())
        } catch (error) {
          isPrivate = String(error?.message ?? error).includes(
            'BlobURLs are not yet supported'
          )
        }
      }
      request.onsuccess = () => {
        request.result.close()
        indexedDB.deleteDatabase(name)
        resolve(isPrivate)
      }
    })
  }
}

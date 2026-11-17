import { Controller } from '@hotwired/stimulus'

// Reloads the page after a short wait, for content a background job is still producing.
export default class extends Controller {
  connect() {
    this.timer = setTimeout(() => window.location.reload(), 3000)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}

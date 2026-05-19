import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['message']
  static values = { url: String }

  async update(event) {
    const eventId = event.detail.value
    if (!eventId) {
      this.messageTarget.textContent = ''
      return
    }
    const response = await fetch(`${this.urlValue}?event_id=${eventId}`)
    const { message } = await response.json()
    this.messageTarget.textContent = message || ''
  }
}

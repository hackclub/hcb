import { Controller } from '@hotwired/stimulus'
import showConfirm from '../confirm'

export default class extends Controller {
  static values = {
    message: { type: String, default: 'Are you sure?' },
    title: { type: String, default: 'Are you sure?' },
    confirmText: { type: String, default: 'Confirm' },
  }

  async request(event) {
    if (
      event.type === 'change' &&
      event.target.type === 'checkbox' &&
      event.target.checked
    )
      return

    if (event.type === 'click') event.preventDefault()

    const confirmed = await showConfirm(this.messageValue, {
      title: this.titleValue,
      confirmText: this.confirmTextValue,
    })

    if (!confirmed) {
      if (event.type === 'change' && event.target.type === 'checkbox') {
        event.target.checked = true
        event.target.dispatchEvent(new Event('change', { bubbles: true }))
      }
      return
    }

    if (event.type === 'click') {
      const checkbox = this.element.querySelector('input[type="checkbox"]')
      if (checkbox) checkbox.checked = true
    }

    this.element.closest('form')?.requestSubmit()
  }
}

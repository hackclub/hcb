import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['field', 'checkbox', 'loader']

  connect() {
    this.fieldTargets.forEach(field => {
      field.addEventListener('change', this.saveWithDebounce.bind(this))
    })

    this.checkboxTarget.addEventListener('change', () =>
      this.loaderTarget.classList.remove('hidden')
    )
  }

  saveWithDebounce(event) {
    clearTimeout(this.saveTimeout)
    this.saveTimeout = setTimeout(() => {
      const form = event.target.closest('form')
      if (form) {
        form.requestSubmit()
      }
    }, 250)
  }
}

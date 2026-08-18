import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['doneForm']
  static values = { formId: String }

  connect() {
    window.addEventListener('message', e => {
      console.log(e)
      // Validate message
      if (
        e.origin !== 'https://links.taxbandits.io' &&
        e.origin !== 'https://testlinks.taxbandits.io'
      )
        return

      const payload = e.data

      if (payload.uid != this.formIdValue) return

      const now = Math.floor(Date.now() / 1000)
      if (typeof payload.iat !== 'number' || Math.abs(now - payload.iat) > 60)
        return

      this.doneFormTarget.requestSubmit()
    })
  }
}

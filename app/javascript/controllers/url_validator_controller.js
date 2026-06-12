import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  handleBlur(event) {
    const input = event.target
    const url = input.value.trim()

    if (!url || this.isValidUrl(url)) return

    const httpsUrl = `https://${url}`
    if (this.isValidUrl(httpsUrl)) {
      input.value = httpsUrl
    }
  }

  isValidUrl(urlString) {
    try {
      new URL(urlString)
      return true
    } catch {
      return false
    }
  }
}

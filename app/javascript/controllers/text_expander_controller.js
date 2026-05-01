import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    // Lazy load text-expander-element only when the controller is first needed
    import('@github/text-expander-element').catch(err => {
      console.error('Failed to load text-expander-element:', err)
    })
  }
}

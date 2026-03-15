import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    // Lazy load popover-polyfill only when the controller is first needed
    // This ensures the polyfill is available for browsers that don't support the popover API natively
    import('@oddbird/popover-polyfill').catch(err => {
      console.error('Failed to load popover-polyfill:', err)
    })
  }
}

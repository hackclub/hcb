import { Controller } from '@hotwired/stimulus'

// Keep the page shown in a paginated frame in the address bar for refreshes.
export default class extends Controller {
  sync() {
    if (!this.element.src) return

    const frameUrl = new URL(this.element.src)
    const currentUrl = new URL(window.location.href)
    const page = frameUrl.searchParams.get('page') || '1'

    if (currentUrl.searchParams.get('page') === page) return

    currentUrl.searchParams.set('page', page)
    window.history.replaceState(window.history.state, '', currentUrl)
  }
}

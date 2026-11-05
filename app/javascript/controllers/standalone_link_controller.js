import { Controller } from '@hotwired/stimulus'

// In an installed PWA there's no browser chrome to come back from, so external
// links have to break out of the standalone window instead of replacing it.
export default class extends Controller {
  connect() {
    if (window.navigator.standalone) this.element.setAttribute('target', '_top')
  }
}

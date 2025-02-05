import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['trigger']

  connect() {
    const isWindows = navigator.userAgent.toUpperCase().indexOf('WIN') >= 0
    this.triggerTarget.setAttribute(
      'aria-label',
      `Jump to (${isWindows ? 'Ctrl' : '⌘'} + K)`
    )
  }
}

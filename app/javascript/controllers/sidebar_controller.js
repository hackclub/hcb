import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['sidebar', 'overlay', 'trigger']

  connect() {}

  disconnect() {}

  open() {
    this.sidebarTarget.style.left = '0'
    this.sidebarTarget.removeAttribute('inert')
    this.sidebarTarget.removeAttribute('aria-hidden')
    this.overlayTarget.classList.remove('overlay--hidden')
  }

  close() {
    this.sidebarTarget.style.left = '-18rem'
    this.sidebarTarget.setAttribute('inert', '')
    this.sidebarTarget.setAttribute('aria-hidden', 'true')
    this.overlayTarget.classList.add('overlay--hidden')
  }
}

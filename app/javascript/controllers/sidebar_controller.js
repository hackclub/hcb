import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['sidebar', 'overlay', 'trigger']

  connect() {
  }

  disconnect() {
  }

  open() {
    this.sidebarTarget.style.left = '0'
    this.overlayTarget.classList.remove('overlay--hidden')
  }

  close() {
    this.sidebarTarget.style.left = '-18rem'
    this.overlayTarget.classList.add('overlay--hidden')
  }
}

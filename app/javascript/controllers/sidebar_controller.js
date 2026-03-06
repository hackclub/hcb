import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['sidebar', 'overlay', 'trigger']

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    this.handleResize = this.handleResize.bind(this)
    document.addEventListener('keydown', this.handleKeydown)
    window.addEventListener('resize', this.handleResize)
    this.handleResize()
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeydown)
    window.removeEventListener('resize', this.handleResize)
  }

  handleKeydown(event) {
    if (event.key === 'Escape' && !this.sidebarTarget.getAttribute('inert'))
      this.close()
  }

  handleResize() {
    const isDesktop = window.innerWidth >= 1024
    this.sidebarTarget.toggleAttribute('inert', !isDesktop)
    this.sidebarTarget.toggleAttribute('aria-hidden', !isDesktop)
    this.overlayTarget.classList.toggle('overlay--hidden', isDesktop)
    this.sidebarTarget.style.left = isDesktop ? '0' : ''
  }

  open() {
    this.sidebarTarget.style.left = '0'
    this.sidebarTarget.removeAttribute('inert')
    this.sidebarTarget.removeAttribute('aria-hidden')
    this.overlayTarget.classList.remove('overlay--hidden')
  }

  close() {
    if (window.innerWidth < 1024) {
      this.sidebarTarget.style.left = '-18rem'
      this.sidebarTarget.setAttribute('inert', '')
      this.sidebarTarget.setAttribute('aria-hidden', 'true')
      this.overlayTarget.classList.add('overlay--hidden')
    }
  }
}

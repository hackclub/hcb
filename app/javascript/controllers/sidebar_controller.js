import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['sidebar', 'overlay', 'toggle']

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    this.handleResize = this.handleResize.bind(this)
    document.addEventListener('keydown', this.handleKeydown)
    window.addEventListener('resize', this.handleResize)
    this.handleResize()
    this.sidebarTarget
      .querySelectorAll(
        '.dock__item:not(summary.dock__item,.user-menu-trigger)'
      )
      .forEach(item => {
        item.addEventListener('click', this.close.bind(this))
      })
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeydown)
    window.removeEventListener('resize', this.handleResize)
  }

  handleKeydown(event) {
    if (event.key === 'Escape' && !this.sidebarTarget.hasAttribute('inert'))
      this.close()
  }

  handleResize() {
    const isDesktop = window.innerWidth >= 1024
    this.sidebarTarget.toggleAttribute('inert', !isDesktop)
    if (isDesktop) {
      this.sidebarTarget.removeAttribute('aria-hidden')
    } else {
      this.sidebarTarget.setAttribute('aria-hidden', 'true')
    }
    this.overlayTarget.classList.add('overlay--hidden')
    this.sidebarTarget.style.left = isDesktop ? '0' : ''
    if (isDesktop) this.toggleTarget.setAttribute('aria-expanded', 'false')
  }

  open() {
    this.sidebarTarget.style.left = '0'
    this.sidebarTarget.removeAttribute('inert')
    this.sidebarTarget.removeAttribute('aria-hidden')
    this.overlayTarget.classList.remove('overlay--hidden')
    this.toggleTarget.setAttribute('aria-expanded', 'true')
  }

  close() {
    if (window.innerWidth < 1024) {
      this.sidebarTarget.style.left = `-${this.sidebarTarget.offsetWidth}px`
      this.sidebarTarget.setAttribute('inert', '')
      this.sidebarTarget.setAttribute('aria-hidden', 'true')
      this.overlayTarget.classList.add('overlay--hidden')
      this.toggleTarget.setAttribute('aria-expanded', 'false')
    }
  }
}

import { Controller } from '@hotwired/stimulus'
import { addLayer, removeLayer } from '../layers'

export default class extends Controller {
  static targets = ['sidebar', 'overlay', 'toggle']

  connect() {
    this.handleResize = this.handleResize.bind(this)
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
    window.removeEventListener('resize', this.handleResize)
    removeLayer(this)
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
    if (isDesktop) {
      this.toggleTarget.setAttribute('aria-expanded', 'false')
      // Always shown on desktop, so there's nothing for Escape to close
      removeLayer(this)
    }
  }

  open() {
    this.sidebarTarget.style.left = '0'
    this.sidebarTarget.removeAttribute('inert')
    this.sidebarTarget.removeAttribute('aria-hidden')
    this.overlayTarget.classList.remove('overlay--hidden')
    this.toggleTarget.setAttribute('aria-expanded', 'true')
    addLayer(this, () => this.close())
  }

  close() {
    if (window.innerWidth < 1024) {
      this.sidebarTarget.style.left = `-${this.sidebarTarget.offsetWidth}px`
      this.sidebarTarget.setAttribute('inert', '')
      this.sidebarTarget.setAttribute('aria-hidden', 'true')
      this.overlayTarget.classList.add('overlay--hidden')
      this.toggleTarget.setAttribute('aria-expanded', 'false')
      removeLayer(this)
    }
  }
}

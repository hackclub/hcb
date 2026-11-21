import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'sidebar',
    'overlay',
    'toggle',
    'scrollContainer',
    'dropdown',
  ]
  static values = { key: String }

  connect() {
    this.restoreState()
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
    cancelAnimationFrame(this.restoreScrollFrame)
    document.removeEventListener('keydown', this.handleKeydown)
    window.removeEventListener('resize', this.handleResize)
  }

  saveState() {
    sessionStorage.setItem(
      `sidebar:${this.keyValue}`,
      JSON.stringify({
        scrollTop: this.scrollContainerTarget.scrollTop,
        dropdowns: this.dropdownTargets
          .filter(dropdown => dropdown.open)
          .map(dropdown => dropdown.dataset.sidebarDropdownKey),
      })
    )
  }

  restoreState() {
    const state = JSON.parse(sessionStorage.getItem(`sidebar:${this.keyValue}`))
    if (!state) return

    // Keep the server's active section open, including on direct settings links.
    this.dropdownTargets.forEach(dropdown => {
      dropdown.open ||= state.dropdowns.includes(
        dropdown.dataset.sidebarDropdownKey
      )
    })
    this.restoreScrollFrame = requestAnimationFrame(() => {
      this.scrollContainerTarget.scrollTop = state.scrollTop
    })
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

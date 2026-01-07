import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['section', 'tab']

  connect() {
    this.observer = new IntersectionObserver(
      (entries) => this.handleIntersection(entries),
      {
        threshold: 0,
        rootMargin: '-100px 0px -66% 0px'
      }
    )

    this.sectionTargets.forEach(section => {
      const heading = section.querySelector('h3')
      if (heading) {
        this.observer.observe(heading)
      }

      section.addEventListener('focusin', () => this.handleFocusIn(section))
    })

    window.addEventListener('scroll', () => this.handleScroll())
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    window.removeEventListener('scroll', () => this.handleScroll())
  }

  handleScroll() {
    const isAtBottom = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 10
    if (isAtBottom) {
      this.activateTab(this.sectionTargets.length - 1)
    }
  }

  handleIntersection(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const section = entry.target.closest('[data-scroll-seek-target="section"]')
        const index = this.sectionTargets.indexOf(section)
        this.activateTab(index)
      }
    })
  }

  handleFocusIn(section) {
    const index = this.sectionTargets.indexOf(section)
    this.activateTab(index)
  }

  activateTab(index) {
    this.tabTargets.forEach(tab => tab.classList.remove('active'))

    if (this.tabTargets[index]) {
      this.tabTargets[index].classList.add('active')
    }
  }
}

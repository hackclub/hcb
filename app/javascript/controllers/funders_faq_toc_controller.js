import { Controller } from '@hotwired/stimulus'

// Funder FAQ table-of-contents: highlights the TOC link for whichever topic section is currently
// near the top of the viewport. Pure progressive enhancement: the TOC jump links work on their own;
// this adds the scroll-tracked active state (visually via `.is-active`, and for assistive tech via
// `aria-current`). No-JS visitors lose nothing.
export default class extends Controller {
  static targets = ['link', 'section']

  connect() {
    this.visible = new Set()
    this.observer = new IntersectionObserver(
      entries => this.onIntersect(entries),
      {
        // Active band: just below the sticky nav down to the top third of the viewport.
        rootMargin: '-80px 0px -70% 0px',
        threshold: 0,
      }
    )
    this.sectionTargets.forEach(section => this.observer.observe(section))
  }

  disconnect() {
    this.observer?.disconnect()
  }

  onIntersect(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) this.visible.add(entry.target)
      else this.visible.delete(entry.target)
    })
    this.update()
  }

  // Highlight the topmost section currently in the active band (not just the first to fire), so fast
  // scrolling can't leave the wrong item lit. When none is in the band we keep the last active.
  update() {
    let current = null
    let bestTop = Infinity
    this.visible.forEach(section => {
      const top = section.getBoundingClientRect().top
      if (top < bestTop) {
        bestTop = top
        current = section
      }
    })
    if (current) this.setActive(current.dataset.tocId)
  }

  setActive(id) {
    this.linkTargets.forEach(link => {
      const active = link.dataset.tocId === id
      link.classList.toggle('is-active', active)
      if (active) {
        link.setAttribute('aria-current', 'true')
      } else {
        link.removeAttribute('aria-current')
      }
    })
  }
}

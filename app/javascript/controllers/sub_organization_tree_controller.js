import { Controller } from '@hotwired/stimulus'

const IN_DURATION = 140
const OUT_DURATION = 100

export default class extends Controller {
  static targets = ['row', 'pinned']

  connect() {
    this.repin = () => this.#requestPin()

    window.addEventListener('scroll', this.repin, { passive: true })
    window.addEventListener('resize', this.repin, { passive: true })
    this.#requestPin()
  }

  disconnect() {
    window.removeEventListener('scroll', this.repin)
    window.removeEventListener('resize', this.repin)
    if (this.pinFrame) cancelAnimationFrame(this.pinFrame)
  }

  async toggle(event) {
    const button = event.currentTarget
    const row = button.closest('tr')

    if (button.getAttribute('aria-expanded') === 'true') {
      button.setAttribute('aria-expanded', 'false')
      await this.#collapse(row)
      this.#requestPin()
      return
    }

    if (row.dataset.loaded === 'true') {
      button.setAttribute('aria-expanded', 'true')
      this.#reveal(row)
      this.#requestPin()
      return
    }

    button.disabled = true
    button.classList.add('sub-organization-row__toggle--loading')

    try {
      const response = await fetch(button.dataset.url, {
        headers: { Accept: 'text/html' },
      })
      if (!response.ok) throw new Error(response.statusText)

      const inserted = this.#insert(row, await response.text())
      row.dataset.loaded = 'true'
      button.setAttribute('aria-expanded', 'true')
      this.#animateIn(inserted)
    } catch (error) {
      // Left collapsed, so a second click retries.
      console.error(error)
    } finally {
      button.disabled = false
      button.classList.remove('sub-organization-row__toggle--loading')
      this.#requestPin()
    }
  }

  // Read back off the DOM rather than waiting for Stimulus to register them as
  // targets, so they can be animated right away.
  #insert(row, html) {
    const stopAt = row.nextElementSibling
    row.insertAdjacentHTML('afterend', html)

    const inserted = []
    for (
      let node = row.nextElementSibling;
      node && node !== stopAt;
      node = node.nextElementSibling
    ) {
      inserted.push(node)
    }
    return inserted
  }

  #reveal(row) {
    const rows = this.#branch(row, { onlyExpanded: true })
    for (const child of rows) child.hidden = false
    this.#animateIn(rows)
  }

  async #collapse(row) {
    const rows = this.#branch(row).filter(child => !child.hidden)

    await this.#animateOut(rows)
    // Each row keeps its expanded state, so re-opening restores the shape.
    for (const child of rows) child.hidden = true
  }

  // Every row under `row`. `onlyExpanded` stops at branches that were already
  // collapsed, which should stay that way.
  #branch(row, { onlyExpanded = false } = {}) {
    const rows = []

    for (const child of this.#childrenOf(row)) {
      rows.push(child)
      if (onlyExpanded && !this.#isExpanded(child)) continue
      rows.push(...this.#branch(child, { onlyExpanded }))
    }
    return rows
  }

  #childrenOf(row) {
    return this.rowTargets.filter(
      candidate => candidate.dataset.parentId === row.dataset.eventId
    )
  }

  #isExpanded(row) {
    return (
      row
        .querySelector('.sub-organization-row__toggle')
        ?.getAttribute('aria-expanded') === 'true'
    )
  }

  #animateIn(rows) {
    if (this.#prefersReducedMotion) return

    for (const row of rows) {
      row.animate(
        [
          { opacity: 0, transform: 'translateY(-0.25rem)' },
          { opacity: 1, transform: 'translateY(0)' },
        ],
        { duration: IN_DURATION, easing: 'cubic-bezier(0.22, 1, 0.36, 1)' }
      )
    }
  }

  async #animateOut(rows) {
    if (this.#prefersReducedMotion || rows.length === 0) return

    const animations = rows.map(row =>
      row.animate(
        [
          { opacity: 1, transform: 'translateY(0)' },
          { opacity: 0, transform: 'translateY(-0.25rem)' },
        ],
        { duration: OUT_DURATION, easing: 'ease-in' }
      )
    )

    // An interrupted animation rejects; hide the rows either way.
    await Promise.allSettled(animations.map(animation => animation.finished))
  }

  get #prefersReducedMotion() {
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches
  }

  #requestPin() {
    if (!this.hasPinnedTarget || this.pinFrame) return

    this.pinFrame = requestAnimationFrame(() => {
      this.pinFrame = null
      this.#pin()
    })
  }

  #pin() {
    const inside = []

    for (const row of this.rowTargets) {
      if (row.hidden || !this.#isExpanded(row)) continue
      if (row.getBoundingClientRect().top > 0) break
      if (this.#branchBottom(row) > 0) inside.push(row)
    }

    this.#renderPinned(inside)
  }

  #branchBottom(row) {
    const depth = Number(row.dataset.depth)
    let last = row

    for (
      let node = row.nextElementSibling;
      node;
      node = node.nextElementSibling
    ) {
      if (!node.classList.contains('sub-organization-row')) break
      if (Number(node.dataset.depth) <= depth) break
      if (!node.hidden) last = node
    }
    return last.getBoundingClientRect().bottom
  }

  #renderPinned(rows) {
    const key = rows.map(row => row.dataset.eventId).join(',')

    if (key !== this.pinnedKey) {
      this.pinnedKey = key
      this.pinnedTarget.replaceChildren(
        ...rows.map(row => this.#pinnedEntry(row))
      )
    }

    let top = 0

    rows.forEach((row, index) => {
      const pin = this.pinnedTarget.children[index]
      const overshoot = Math.min(
        0,
        this.#branchBottom(row) - (top + pin.offsetHeight)
      )

      pin.style.transform = overshoot ? `translateY(${overshoot}px)` : ''
      pin.style.zIndex = String(rows.length - index)
      top += pin.offsetHeight
    })
  }

  #pinnedEntry(row) {
    const entry = document.createElement('a')
    entry.className = 'sub-organization-row__pin'
    entry.href = row.querySelector('a.stretched-link').href

    const name = row
      .querySelector('.sub-organization-row__name')
      .cloneNode(true)
    const toggle = name.querySelector('button')

    if (toggle) {
      const caret = document.createElement('span')
      caret.className = `${toggle.className} sub-organization-row__toggle--open`
      caret.innerHTML = toggle.innerHTML
      toggle.replaceWith(caret)
    }

    entry.append(name)
    return entry
  }
}

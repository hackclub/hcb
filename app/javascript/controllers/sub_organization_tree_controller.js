import { Controller } from '@hotwired/stimulus'

const LIFTED = { opacity: 0, transform: 'translateY(-0.25rem)' }
const RESTING = { opacity: 1, transform: 'translateY(0)' }

const FADE_IN = {
  keyframes: [LIFTED, RESTING],
  duration: 140,
  easing: 'cubic-bezier(0.22, 1, 0.36, 1)',
}
const FADE_OUT = {
  keyframes: [RESTING, LIFTED],
  duration: 100,
  easing: 'ease-in',
}

export default class extends Controller {
  static targets = ['row', 'pinned']

  connect() {
    this.repin = () => this.#requestPin()

    for (const event of ['scroll', 'resize']) {
      window.addEventListener(event, this.repin, { passive: true })
    }
    this.#requestPin()
  }

  disconnect() {
    for (const event of ['scroll', 'resize']) {
      window.removeEventListener(event, this.repin)
    }
    if (this.pinFrame) cancelAnimationFrame(this.pinFrame)
  }

  async toggle(event) {
    const button = event.currentTarget
    const row = button.closest('tr')
    const expand = button.getAttribute('aria-expanded') !== 'true'

    try {
      if (!expand) await this.#collapse(row)
      else if (row.dataset.loaded === 'true') this.#reveal(row)
      else await this.#load(row, button)

      button.setAttribute('aria-expanded', String(expand))
    } catch (error) {
      // Left as it was, so a second click retries.
      console.error(error)
    } finally {
      this.#requestPin()
    }
  }

  async #load(row, button) {
    button.disabled = true
    button.classList.add('sub-organization-row__toggle--loading')

    try {
      const response = await fetch(button.dataset.url, {
        headers: { Accept: 'text/html' },
      })
      if (!response.ok) throw new Error(response.statusText)

      // A template parses `<tr>` outside a table, and holding the rows before
      // they are inserted animates them without waiting on Stimulus targets.
      const template = document.createElement('template')
      template.innerHTML = await response.text()
      const inserted = [...template.content.children]

      row.after(template.content)
      row.dataset.loaded = 'true'
      this.#animate(inserted, FADE_IN)
    } finally {
      button.disabled = false
      button.classList.remove('sub-organization-row__toggle--loading')
    }
  }

  #reveal(row) {
    const rows = this.#branch(row, { onlyExpanded: true })

    for (const child of rows) child.hidden = false
    this.#animate(rows, FADE_IN)
  }

  async #collapse(row) {
    const rows = this.#branch(row).filter(child => !child.hidden)

    await this.#animate(rows, FADE_OUT)
    // Each row keeps its expanded state, so re-opening restores the shape.
    for (const child of rows) child.hidden = true
  }

  // Every row nested under `row`, in document order. `onlyExpanded` skips the
  // branches that were already collapsed, which should stay that way.
  #branch(row, { onlyExpanded = false } = {}) {
    const depth = Number(row.dataset.depth)
    const rows = []
    let collapsedAt = Infinity

    for (
      let node = row.nextElementSibling;
      node?.classList.contains('sub-organization-row');
      node = node.nextElementSibling
    ) {
      const nodeDepth = Number(node.dataset.depth)

      if (nodeDepth <= depth) break
      if (nodeDepth > collapsedAt) continue

      collapsedAt =
        onlyExpanded && !this.#isExpanded(node) ? nodeDepth : Infinity
      rows.push(node)
    }
    return rows
  }

  #isExpanded(row) {
    return (
      row
        .querySelector('.sub-organization-row__toggle')
        ?.getAttribute('aria-expanded') === 'true'
    )
  }

  // An interrupted animation rejects; settle either way so the caller can hide
  // the rows once they have faded.
  #animate(rows, { keyframes, ...timing }) {
    if (this.#prefersReducedMotion || rows.length === 0) return

    return Promise.allSettled(
      rows.map(row => row.animate(keyframes, timing).finished)
    )
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
    const visible = this.#branch(row).filter(child => !child.hidden)

    return (visible.at(-1) ?? row).getBoundingClientRect().bottom
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

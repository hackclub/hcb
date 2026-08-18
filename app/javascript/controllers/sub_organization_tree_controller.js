import { Controller } from '@hotwired/stimulus'

const IN_DURATION = 200
const OUT_DURATION = 120
// Rows come in one after another rather than all at once, which reads as a
// branch unfolding. Past a handful of rows the stagger stops growing, so a wide
// branch doesn't take noticeably longer to arrive than a narrow one.
const STAGGER = 25
const MAX_STAGGERED_ROWS = 8

// Expands and collapses branches of the sub-organization table. A level is
// fetched the first time it is expanded and then kept around, so collapsing and
// re-expanding a branch costs nothing and keeps whatever was open below it.
export default class extends Controller {
  static targets = ['row']

  async toggle(event) {
    const button = event.currentTarget
    const row = button.closest('tr')

    if (button.getAttribute('aria-expanded') === 'true') {
      button.setAttribute('aria-expanded', 'false')
      await this.#collapse(row)
      return
    }

    if (row.dataset.loaded === 'true') {
      button.setAttribute('aria-expanded', 'true')
      this.#reveal(row)
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
      // Leaving the branch collapsed lets the viewer try again by clicking it
      // a second time.
      console.error(error)
    } finally {
      button.disabled = false
      button.classList.remove('sub-organization-row__toggle--loading')
    }
  }

  // The rows are inserted straight after their parent's, and returned in the
  // order they now sit in. Reading them back off the DOM rather than waiting
  // for Stimulus to pick them up as targets keeps them animatable right away.
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
    // Each row keeps its own expanded state, so re-opening this branch restores
    // the shape it was left in.
    for (const child of rows) child.hidden = true
  }

  // Every row under `row`, top down. With `onlyExpanded`, it stops at branches
  // that were collapsed when their parent was, which are the ones that should
  // stay collapsed now that it is opening again.
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

    rows.forEach((row, index) => {
      row.animate(
        [
          { opacity: 0, transform: 'translateY(-0.35rem)' },
          { opacity: 1, transform: 'translateY(0)' },
        ],
        {
          duration: IN_DURATION,
          delay: Math.min(index, MAX_STAGGERED_ROWS) * STAGGER,
          easing: 'cubic-bezier(0.22, 1, 0.36, 1)',
          fill: 'backwards',
        }
      )
    })
  }

  async #animateOut(rows) {
    if (this.#prefersReducedMotion || rows.length === 0) return

    const animations = rows.map(row =>
      row.animate(
        [
          { opacity: 1, transform: 'translateY(0)' },
          { opacity: 0, transform: 'translateY(-0.35rem)' },
        ],
        { duration: OUT_DURATION, easing: 'ease-in' }
      )
    )

    // An interrupted animation rejects; the rows still need hiding either way.
    await Promise.allSettled(animations.map(animation => animation.finished))
  }

  get #prefersReducedMotion() {
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches
  }
}

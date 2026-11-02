import { Controller } from '@hotwired/stimulus'

// Same key and JSON encoding Alpine's `$persist` used, so existing pins survive.
const STORAGE_KEY = '_x_pinned_cards'

// Admin tool cards can be pinned to a grid at the top of the page. Pinning
// moves the card's DOM node into that grid and remembers where it came from, so
// unpinning can put it back. The list survives reloads via localStorage.
export default class extends Controller {
  static targets = ['pinnedSection', 'pinnedGrid', 'pin']

  connect() {
    const stored = localStorage.getItem(STORAGE_KEY)
    this.pinnedCards = stored === null ? [] : JSON.parse(stored)

    this.pinnedCards.forEach(({ id }) => {
      this.pinnedGridTarget.appendChild(document.getElementById(id))
    })
    this.pinnedSectionTarget.hidden = this.pinnedCards.length == 0
    this.render()
  }

  pin({ currentTarget }) {
    const id = currentTarget.closest('a').parentElement.id
    const element = document.getElementById(id)
    const pinned = this.pinnedCards.find(card => card.id === id)
    const wasEmpty = this.pinnedCards.length == 0

    if (pinned) {
      this.pinnedCards = this.pinnedCards.filter(card => card.id !== id)
      document.getElementById(pinned.old_grid_id).appendChild(element)
    } else {
      const old_grid_id = currentTarget.closest('.grid').id
      this.pinnedCards.push({ id, old_grid_id })
      this.pinnedGridTarget.appendChild(element)
    }

    localStorage.setItem(STORAGE_KEY, JSON.stringify(this.pinnedCards))
    if (wasEmpty != (this.pinnedCards.length == 0)) this.toggleSection()
    this.render()
  }

  render() {
    this.pinTargets.forEach(icon => {
      const pinned = this.isPinned(icon.closest('a').parentElement.id)
      icon.setAttribute('color', pinned ? 'orange' : 'var(--muted)')
      icon.classList.toggle('opacity-100', pinned)
      icon.classList.toggle('opacity-0', !pinned)
    })
  }

  // Mirrors Alpine's default `x-transition`: fade and scale from 95%, 150ms in
  // and 75ms out.
  toggleSection() {
    const section = this.pinnedSectionTarget
    const show = this.pinnedCards.length > 0
    const keyframes = [
      { opacity: 0, transform: 'scale(0.95)' },
      { opacity: 1, transform: 'scale(1)' },
    ]
    const easing = 'cubic-bezier(0.4, 0, 0.2, 1)'

    section.getAnimations().forEach(animation => animation.cancel())

    if (show) {
      section.hidden = false
      section.animate(keyframes, { duration: 150, easing })
    } else {
      section
        .animate([...keyframes].reverse(), { duration: 75, easing })
        .finished.then(() => (section.hidden = true))
        .catch(() => {})
    }
  }

  isPinned(id) {
    return this.pinnedCards.some(card => card.id === id)
  }
}

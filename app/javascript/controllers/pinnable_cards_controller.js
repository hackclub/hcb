import { Controller } from '@hotwired/stimulus'

const STORAGE_KEY = 'admin_tools:pinned_cards'

// Lets admins pin task cards to the top of the page. Pinning moves the card's
// element into the pinned grid and remembers where it came from, so unpinning
// can put it back.
export default class extends Controller {
  static targets = ['grid', 'section']

  connect() {
    this.pinned = this.read()
    this.pinned.forEach(({ id }) => {
      const card = document.getElementById(id)
      if (card) this.gridTarget.appendChild(card)
    })

    this.render()
  }

  toggle(event) {
    event.preventDefault()

    const card = event.currentTarget.closest('a').parentElement
    const id = card.id

    if (this.isPinned(id)) {
      const { grid } = this.pinned.find(entry => entry.id === id)
      this.pinned = this.pinned.filter(entry => entry.id !== id)
      document.getElementById(grid)?.appendChild(card)
    } else {
      this.pinned = [
        ...this.pinned,
        { id, grid: event.currentTarget.closest('.grid').id },
      ]
      this.gridTarget.appendChild(card)
    }

    this.write()
    this.render()
  }

  render() {
    this.sectionTarget.style.display = this.pinned.length > 0 ? '' : 'none'

    this.element.querySelectorAll('[data-pinnable-cards-pin]').forEach(pin => {
      const pinned = this.isPinned(pin.closest('a').parentElement.id)

      pin.setAttribute('color', pinned ? 'orange' : 'var(--muted)')
      pin.classList.toggle('opacity-100', pinned)
      pin.classList.toggle('opacity-0', !pinned)
    })
  }

  isPinned(id) {
    return this.pinned.some(entry => entry.id === id)
  }

  read() {
    try {
      const stored = JSON.parse(localStorage.getItem(STORAGE_KEY))
      return Array.isArray(stored) ? stored : []
    } catch {
      return []
    }
  }

  write() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(this.pinned))
  }
}

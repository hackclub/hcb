import { Controller } from '@hotwired/stimulus'

// Admin tool cards can be pinned to a grid at the top of the page. Pinning moves
// the card into that grid and remembers the grid it came from, so unpinning can
// put it back. Pins are kept in localStorage with the key and format Alpine's
// `$persist` wrote before this controller (a JSON array of `{ id, old_grid_id }`
// under `_x_pinned_cards`), so pins made back then survive.
const STORAGE_KEY = '_x_pinned_cards'

export default class extends Controller {
  static targets = ['section', 'grid', 'pin']

  connect() {
    this.pins = this.load()

    this.pins.forEach(({ id }) => {
      // A card can be renamed or removed after it was pinned.
      const card = document.getElementById(id)
      if (card) this.gridTarget.appendChild(card)
    })

    this.render()
  }

  toggle({ currentTarget }) {
    const card = currentTarget.closest('a').parentElement
    const pin = this.pins.find(({ id }) => id === card.id)

    if (pin) {
      this.pins = this.pins.filter(({ id }) => id !== card.id)
      document.getElementById(pin.old_grid_id).appendChild(card)
    } else {
      this.pins.push({ id: card.id, old_grid_id: card.closest('.grid').id })
      this.gridTarget.appendChild(card)
    }

    this.save()
    this.render()
  }

  render() {
    this.sectionTarget.hidden = this.pins.length === 0

    this.pinTargets.forEach(icon => {
      const cardId = icon.closest('a').parentElement.id
      const pinned = this.pins.some(({ id }) => id === cardId)

      icon.setAttribute('color', pinned ? 'orange' : 'var(--muted)')
      icon.classList.toggle('opacity-100', pinned)
      icon.classList.toggle('opacity-0', !pinned)
    })
  }

  load() {
    try {
      const pins = JSON.parse(localStorage.getItem(STORAGE_KEY))
      return Array.isArray(pins) ? pins : []
    } catch {
      return []
    }
  }

  save() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.pins))
    } catch {
      // Storage is unavailable (private mode, quota): pins last until reload.
    }
  }
}

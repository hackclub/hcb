import Alpine from '@alpinejs/csp'

// Admin tool cards can be pinned to a grid at the top of the page. Pinning
// moves the card's DOM node into that grid and remembers where it came from, so
// unpinning can put it back. The list survives reloads via the persist plugin.
export default () => ({
  // No `.as(...)`: the auto key (`_x_pinned_cards`) is the one the inline
  // `$persist([])` already wrote, so existing pins survive.
  pinned_cards: Alpine.$persist([]),

  pin(id, old_grid_id) {
    this.isPinned(id)
      ? this.remove_and_respawn_card(id)
      : this.push_and_teleport_card(id, old_grid_id)
  },

  push_and_teleport_card(id, old_grid_id) {
    this.pinned_cards.push({ id, old_grid_id })
    this.$refs.pinnedGrid.appendChild(document.getElementById(id))
  },

  remove_and_respawn_card(id) {
    const { old_grid_id } = this.pinned_cards.find(card => card.id === id)
    this.pinned_cards = this.pinned_cards.filter(card => card.id !== id)
    document
      .getElementById(old_grid_id)
      .appendChild(document.getElementById(id))
  },

  teleport_mass_cards() {
    this.pinned_cards.forEach(({ id }) => {
      this.$refs.pinnedGrid.appendChild(document.getElementById(id))
    })
  },

  isPinned(id) {
    return this.pinned_cards.find(card => card.id === id)
  },
})

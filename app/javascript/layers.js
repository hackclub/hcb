// Everything open over the page, like modals and menus, in the order it opened,
// so Escape closes only the top one. Each adds itself with how to close it.
const layers = new Map()

export function addLayer(owner, close) {
  prune()
  layers.set(owner, close)
}

export function removeLayer(owner) {
  layers.delete(owner)
}

// Turbo can replace one without it closing, which would otherwise keep the old
// page alive and leave it on top
function prune() {
  for (const owner of layers.keys())
    if (owner.isConnected === false) layers.delete(owner)
}

// On window, so it runs last: anything that handles Escape itself (a combobox's
// suggestions, an inline edit) claims it first with preventDefault
window.addEventListener('keydown', event => {
  if (
    event.key !== 'Escape' ||
    event.isComposing ||
    event.defaultPrevented ||
    !layers.size
  )
    return

  prune()
  if (!layers.size) return

  // Or the browser would close the top <dialog> too
  event.preventDefault()
  ;[...layers.values()].at(-1)()
})

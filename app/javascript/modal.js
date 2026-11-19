import { Turbo } from '@hotwired/turbo-rails'
import { addLayer, removeLayer } from './layers'

// Modals are native <dialog>s (ModalHelper#modal), so the browser stacks them
// and traps focus, and Escape closes the top one (app/javascript/layers.js).
// Everything here is delegated from the document, so a page with hundreds of
// modals costs nothing until one opens.

// Where each open modal was rendered, so closing it can put it back
const origins = new WeakMap()
// Modals animating out, so reopening one mid-animation keeps it open
const closing = new WeakMap()

// An id or the <dialog> itself
const find = target =>
  typeof target === 'string' ? document.getElementById(target) : target

export function openModal(target, trigger = null) {
  const dialog = find(target)
  if (!dialog) return

  closing.delete(dialog)
  delete dialog.dataset.closing
  // Where it's rendered, it would inherit styles like a table row's
  // `pointer-events: none`, open invisible under a hidden ancestor, and only
  // navigate the turbo-frame around it, so it opens from <body> instead
  if (!dialog.open && dialog.parentElement !== document.body) lift(dialog)

  document.dispatchEvent(new CustomEvent('hcb:close-menus'))
  dialog.querySelectorAll('iframe[data-src]').forEach(iframe => {
    iframe.src ||= iframe.dataset.src
  })
  // Fired when already open too, so a modal like the popover can load something else
  dialog.dispatchEvent(new CustomEvent('modal:open', { detail: { trigger } }))
  if (!dialog.open) dialog.showModal()
  addLayer(dialog, () => closeModal(dialog))
}

// Animates it out, then closes it. `dialog.close()` closes it at once.
export function closeModal(target) {
  const dialog = find(target)
  if (!dialog?.open || closing.has(dialog)) return

  const run = {}
  closing.set(dialog, run)
  dialog.dataset.closing = ''
  // Already on its way out, so Escape moves on to what's beneath
  removeLayer(dialog)
  // Ones opened from inside it go with it
  document.querySelectorAll('dialog[open]').forEach(other => {
    if (other !== dialog && dialog.contains(origins.get(other) ?? other))
      closeModal(other)
  })
  Promise.allSettled(
    dialog.getAnimations().map(({ finished }) => finished)
  ).then(() => closing.get(dialog) === run && dialog.close())
}

function lift(dialog) {
  const origin = new Comment('modal')
  dialog.replaceWith(origin)
  document.body.append(dialog)
  origins.set(dialog, origin)
}

function restore(dialog) {
  const origin = origins.get(dialog)
  if (!origin) return

  origins.delete(dialog)
  // Its page was replaced while it was open (a frame reloaded, say)
  if (origin.isConnected) origin.replaceWith(dialog)
  else dialog.remove()
}

document.addEventListener('click', event => {
  const close = event.target.closest('[data-modal-close]')
  if (close) {
    event.preventDefault()
    closeModal(close.closest('dialog'))
    return
  }

  const trigger = event.target.closest('[data-modal]')
  if (!trigger) return

  // A link or button inside the trigger does its own thing
  const control = event.target.closest(
    'a[href], button, input, select, textarea'
  )
  if (control && control !== trigger && trigger.contains(control)) return
  // Let modifier clicks open the link in a new tab
  if (
    trigger.matches('a[href]') &&
    (event.metaKey || event.ctrlKey || event.shiftKey)
  )
    return

  event.preventDefault()
  openModal(trigger.dataset.modal, trigger)
})

// Clicking the backdrop closes the modal, unless the press started inside it (selecting text, say)
const onBackdrop = ({ target, clientX, clientY }) => {
  if (!target.matches?.(':modal')) return false
  const { top, right, bottom, left } = target.getBoundingClientRect()
  return clientY < top || clientY > bottom || clientX < left || clientX > right
}
let pressedBackdrop = false
document.addEventListener('pointerdown', event => {
  pressedBackdrop = onBackdrop(event)
})
document.addEventListener('click', event => {
  if (pressedBackdrop && onBackdrop(event)) closeModal(event.target)
})

// Other close requests, like Android's back gesture, animate out too. `cancel`
// doesn't bubble, so listen while it captures.
document.addEventListener(
  'cancel',
  event => {
    if (!event.target.matches?.('.modal')) return
    event.preventDefault()
    closeModal(event.target)
  },
  true
)

// `close` doesn't bubble, so listen while it captures
document.addEventListener(
  'close',
  ({ target }) => {
    if (!(target instanceof HTMLDialogElement)) return

    closing.delete(target)
    delete target.dataset.closing
    removeLayer(target)
    // Modals opened from inside this one would otherwise stay open, invisible, blocking the page
    document.querySelectorAll('dialog[open]').forEach(dialog => {
      if (target.contains(origins.get(dialog) ?? dialog)) dialog.close()
    })
    restore(target)
  },
  true
)

// Leave no modal open in the snapshot that back/forward restores
document.addEventListener('turbo:before-cache', () => {
  document.querySelectorAll('dialog[open]').forEach(dialog => {
    dialog.close()
    restore(dialog)
  })
})

// A morph refresh removes `open`, which hides a modal but leaves it blocking the page
document.addEventListener('turbo:before-morph-attribute', event => {
  if (
    event.target instanceof HTMLDialogElement &&
    event.detail.attributeName === 'open'
  ) {
    event.preventDefault()
    event.target.close()
  }
})

Turbo.StreamActions.open_modal = function () {
  openModal(this.target)
}

import { Turbo } from '@hotwired/turbo-rails'

// Modals are native <dialog>s (ModalHelper#modal), so the browser stacks them,
// traps focus and closes the top one on Escape. Everything here is delegated
// from the document, so a page with hundreds of modals costs nothing until one opens.

// Where each open modal was rendered, so closing it can put it back
const origins = new WeakMap()

export function openModal(target, trigger = null) {
  const dialog =
    typeof target === 'string' ? document.getElementById(target) : target
  if (!dialog) return

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
    close.closest('dialog')?.close()
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
  if (pressedBackdrop && onBackdrop(event)) event.target.close()
})

// `close` doesn't bubble, so listen while it captures
document.addEventListener(
  'close',
  ({ target }) => {
    if (!(target instanceof HTMLDialogElement)) return

    // Modals opened from inside this one would otherwise stay open, invisible, blocking the page
    document.querySelectorAll('dialog[open]').forEach(dialog => {
      if (target.contains(origins.get(dialog) ?? dialog)) dialog.close()
    })

    Promise.allSettled(
      target.getAnimations().map(({ finished }) => finished)
    ).then(() => target.open || restore(target))
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

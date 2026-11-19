import { Turbo } from '@hotwired/turbo-rails'
import { addLayer, removeLayer } from './layers'

// Modals are native <dialog>s (ModalHelper#modal), opened with `show()` rather
// than `showModal()`. That would make the rest of the page inert, which
// restyles the whole page, twice per modal, and on a long ledger was most of
// what a click cost. So what it would have done is done here instead: each
// modal gets a backdrop that covers the page, the open ones are stacked in the
// order they opened, and focus is kept inside the top one. Escape closes the
// top one too (app/javascript/layers.js).
// Everything here is delegated from the document, so a page with hundreds of
// modals costs nothing until one opens.

// Where each open modal was rendered, so closing it can put it back
const origins = new WeakMap()
// Modals animating out, so reopening one mid-animation keeps it open
const closing = new WeakMap()
// The modal each open one was opened from, which closing closes it too
const openers = new WeakMap()
// Each modal's backdrop, which sits right before it while it's open
const backdrops = new WeakMap()
// The open modals, bottom to top
let stack = []

// The one that's open on top of the rest, and isn't on its way out
const topModal = () => {
  // Turbo can replace the page without any of them closing
  stack = stack.filter(dialog => dialog.isConnected && dialog.open)
  return stack.findLast(dialog => !closing.has(dialog))
}

// An id or the <dialog> itself
const find = target =>
  typeof target === 'string' ? document.getElementById(target) : target

const openedFrom = opener =>
  [...document.querySelectorAll('dialog[open]')].filter(
    dialog => openers.get(dialog) === opener
  )

export function openModal(target, trigger = null) {
  const dialog = find(target)
  if (!dialog) return

  // Read before anything changes, when it costs no layout
  if (!topModal()) scrolled = { left: scrollX, top: scrollY }
  closing.delete(dialog)
  delete dialog.dataset.closing
  const backdrop = backdrops.get(dialog)
  if (backdrop) delete backdrop.dataset.closing
  if (!dialog.open) {
    // Its trigger's modal, or the one it's rendered in when opened from code
    openers.set(dialog, (trigger ?? dialog.parentElement).closest('dialog'))
    // Where it's rendered, it would inherit styles like a table row's
    // `pointer-events: none`, open invisible under a hidden ancestor, and only
    // navigate the turbo-frame around it, so it opens from <body> instead
    if (dialog.parentElement !== document.body) lift(dialog)
  }

  document.dispatchEvent(new CustomEvent('hcb:close-menus'))
  dialog.querySelectorAll('iframe[data-src]').forEach(iframe => {
    iframe.src ||= iframe.dataset.src
  })
  // Fired when already open too, so a modal like the popover can load something else
  dialog.dispatchEvent(new CustomEvent('modal:open', { detail: { trigger } }))
  if (!dialog.open) show(dialog)
  addLayer(dialog, () => closeModal(dialog))
}

function show(dialog) {
  stack = stack.filter(other => other !== dialog && other.isConnected)
  // Above the ones already open, wherever each is in the page
  for (const layer of [backdropFor(dialog), dialog])
    if (stack.length) layer.style.setProperty('--modal-depth', stack.length)
    else layer.style.removeProperty('--modal-depth')
  stack.push(dialog)

  dialog.before(backdropFor(dialog))
  // Focuses the first thing in it, and remembers what to hand focus back to
  dialog.show()
  trapFocus()
}

function backdropFor(dialog) {
  let backdrop = backdrops.get(dialog)
  if (backdrop) return backdrop

  backdrop = document.createElement('div')
  backdrop.className = 'modal-backdrop'
  // Never part of the page that Back restores
  backdrop.dataset.turboTemporary = ''
  // A press that started inside the modal (selecting text, say) clicks their
  // common ancestor instead, so this is only ever a click on the backdrop
  backdrop.addEventListener('click', () => {
    if (topModal() === dialog) closeModal(dialog)
  })
  backdrops.set(dialog, backdrop)
  return backdrop
}

// Once it's closed
function settle(dialog) {
  closing.delete(dialog)
  delete dialog.dataset.closing
  dialog.style.removeProperty('--modal-depth')
  backdrops.get(dialog)?.remove()
  stack = stack.filter(other => other !== dialog)
  removeLayer(dialog)
  if (!stack.length) releaseFocus()
}

// Animates it out, then closes it. `dialog.close()` closes it at once.
export function closeModal(target) {
  const dialog = find(target)
  if (!dialog?.open || closing.has(dialog)) return

  const run = {}
  closing.set(dialog, run)
  dialog.dataset.closing = ''
  const backdrop = backdrops.get(dialog)
  if (backdrop) backdrop.dataset.closing = ''
  // Already on its way out, so Escape moves on to what's beneath
  removeLayer(dialog)
  // Ones opened from it go with it
  openedFrom(dialog).forEach(closeModal)
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
  if (origin.isConnected) origin.replaceWith(dialog)
  // Its page was replaced while it was open (a frame reloaded, say), unless a
  // morph refresh put it back in its place
  else if (dialog.parentElement === document.body) dialog.remove()
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

// Other close requests, like Android's back gesture, animate out too (a modal
// is `closedby="closerequest"`, as one opened with `show()` gets none
// otherwise). Escape never gets here: app/javascript/layers.js claims it.
// `cancel` doesn't bubble, so listen while it captures.
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
    // It fires a task later, by when it may have opened again
    if (!(target instanceof HTMLDialogElement) || target.open) return

    settle(target)
    // Ones opened from it would otherwise outlive it, invisibly and blocking
    // the page if they're rendered inside it
    openedFrom(target).forEach(dialog => dialog.close())
    restore(target)
  },
  true
)

// Leave no modal open in the snapshot that back/forward restores
document.addEventListener('turbo:before-cache', () => {
  document.querySelectorAll('dialog[open]').forEach(dialog => {
    dialog.close()
    settle(dialog)
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

// Keeps focus in the top modal, as the page behind it can still take it. Only
// listening while a modal is open.
const focusable =
  'a[href], button, input, select, textarea, summary, iframe, [tabindex], [contenteditable]'
const tabbable = element =>
  element.tabIndex >= 0 &&
  !element.matches(':disabled') &&
  !element.closest('[inert]') &&
  element.checkVisibility({ visibilityProperty: true })
// The first and last things Tab stops at in it
const ends = dialog => {
  const candidates = [...dialog.querySelectorAll(focusable)]
  return [candidates.find(tabbable), candidates.findLast(tabbable)]
}
// Not the page behind, but something shown over the modal that looks after
// focus itself: a SweetAlert, the command bar, or anything in the browser's
// top layer
const above = element =>
  element.closest?.('.swal-overlay, [data-above-modals], :modal')

let trapping = false
let backwards = false
// Where the page was scrolled to when the first modal opened
let scrolled = null

function trapFocus() {
  if (trapping) return
  trapping = true
  document.addEventListener('keydown', wrapTab)
  document.addEventListener('focusin', keepFocus)
}

function releaseFocus() {
  if (!trapping) return
  trapping = false
  document.removeEventListener('keydown', wrapTab)
  document.removeEventListener('focusin', keepFocus)
}

// Tab past either end comes around to the other, before focus ever leaves
function wrapTab(event) {
  if (event.key !== 'Tab' || event.ctrlKey || event.metaKey || event.altKey)
    return
  const dialog = topModal()
  if (!dialog) return releaseFocus()

  backwards = event.shiftKey
  const active = document.activeElement
  // Handled already, by a field that completes on Tab, say
  if (event.defaultPrevented || above(active)) return

  const [first, last] = ends(dialog)
  const within = node => !!node && node !== dialog && dialog.contains(node)
  // Between the ends, the browser knows the way: on from what has focus, or
  // from where the last click landed when nothing has
  if (within(active) ? active !== (backwards ? first : last) : clickedIn())
    return

  event.preventDefault()
  ;(backwards ? last : first)?.focus()

  function clickedIn() {
    return (
      (active === document.body || active === dialog) &&
      within(getSelection()?.anchorNode)
    )
  }
}

// And anything else that takes focus out (tabbing in from the address bar, or
// out of an iframe or radio group at an end) has it put back
function keepFocus({ target }) {
  const dialog = topModal()
  if (!dialog) return releaseFocus()
  if (dialog.contains(target) || above(target)) return

  const [first, last] = ends(dialog)
  ;(backwards ? last : first)?.focus()
  // Focus scrolled the page to whatever took it
  if (scrolled) scrollTo({ ...scrolled, behavior: 'instant' })
}

Turbo.StreamActions.open_modal = function () {
  openModal(this.target)
}

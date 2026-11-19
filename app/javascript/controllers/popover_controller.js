import { Controller } from '@hotwired/stimulus'
import { Turbo } from '@hotwired/turbo-rails'
import { closeModal, openModal } from '../modal'

// The side panel that loads whichever transaction, card or payment was clicked
// (PopoverHelper builds the links), with its URL in ?popover= so it survives a
// reload and closes with Back.
export default class extends Controller {
  static targets = ['title', 'externalLink', 'flash', 'body', 'loading']

  connect() {
    this.openFromUrl()
  }

  // Also run as frames load, since the link for ?popover= may be in a lazy one,
  // and after a morph refresh, which closes it like a reload would
  openFromUrl() {
    const stateUrl = new URL(location.href).searchParams.get('popover')
    if (!stateUrl || (this.element.open && stateUrl === this.stateUrl)) return

    const trigger = document.querySelector(
      `[data-popover-state-url="${CSS.escape(stateUrl)}"]`
    )
    if (trigger) openModal(this.element, trigger)
  }

  populate({ detail: { trigger } }) {
    const {
      popoverTitle: title = '',
      popoverSrc: src,
      popoverFrameId: frameId,
      popoverStateUrl: stateUrl,
      popoverStateTitle: stateTitle = title,
      popoverExternalLink: externalLink,
      popoverSize: size,
    } = trigger.dataset

    this.stateUrl = stateUrl
    this.titleTarget.textContent = title
    this.externalLinkTarget.href = externalLink ?? '#'
    this.externalLinkTarget.style.display = externalLink ? '' : 'none'
    this.element.classList.toggle('modal--popover--sm', size === 'sm')
    this.flashTarget.replaceChildren()
    this.bodyTarget.replaceChildren()

    if (src && frameId) {
      const frame = document.createElement('turbo-frame')
      frame.id = frameId
      frame.setAttribute('target', '_top')
      frame.dataset.popoverSrc = src
      frame.append(this.loadingTarget.content.cloneNode(true))
      frame.src = src
      this.bodyTarget.append(frame)
    }

    if (!stateUrl) return
    this.pageTitle ??= document.title
    document.title = stateTitle
    const url = new URL(location.href)
    if (url.searchParams.get('popover') !== stateUrl) {
      url.searchParams.set('popover', stateUrl)
      history.pushState({ popover: true }, '', url)
    }
  }

  closed() {
    // Reopened, after a morph refresh, before this ran
    if (this.element.open) return

    // Closing with Back has already dropped it
    const url = new URL(location.href)
    if (this.stateUrl && url.searchParams.get('popover') === this.stateUrl) {
      url.searchParams.delete('popover')
      history.pushState(null, '', url)
    }
    if (this.pageTitle) document.title = this.pageTitle

    this.stateUrl = this.pageTitle = null
    this.bodyTarget.replaceChildren()
    this.flashTarget.replaceChildren()
    this.element.classList.remove(
      'modal--popover--sm',
      'modal--popover--receipt-expanded'
    )
  }

  popstate({ state }) {
    if (state?.popover) this.openFromUrl()
    else closeModal(this.element)
  }

  // Pages loaded with ?popover= echo it into links built from the query string
  beforeVisit(event) {
    const url = new URL(event.detail.url)
    if (
      document.querySelector('dialog:modal') ||
      !url.searchParams.has('popover')
    )
      return

    event.preventDefault()
    url.searchParams.delete('popover')
    Turbo.visit(url.href)
  }
}

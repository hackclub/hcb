import { Controller } from '@hotwired/stimulus'
import {
  autoUpdate,
  computePosition,
  flip,
  offset,
  size,
} from '@floating-ui/dom'
import gsap from 'gsap'
import { addLayer, removeLayer } from '../layers'

export default class extends Controller {
  static targets = ['toggle', 'content']

  static values = {
    appendTo: String,
    placement: { type: String, default: 'bottom-start' },
    contentId: String,
    updateOnResize: { type: Boolean, default: false }, // See https://github.com/hackclub/hcb/issues/8588
  }

  initialize() {
    this.isOpen = false
    // Added to the page only while open, so a page of closed menus costs nothing
    this.closeOnOutsideClick = event => this.close(event)
    this.closeOnRequest = () => this.close()
  }

  // Also removes the cloned menu, so it doesn't outlive a turbo frame update
  disconnect() {
    this.close()
  }

  toggle(e) {
    e.preventDefault()

    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    if (this.isOpen) return
    if (!this.hasContentTarget) return
    // Open from here on, not once it's positioned, so a quick second click or
    // Escape before then closes this menu rather than opening another
    this.isOpen = true
    this.toggleTarget.setAttribute('aria-expanded', true)

    // The content can be a <template> wrapping the menu, which keeps its links
    // and forms out of the page until it opens (a menu inside a link can't
    // otherwise hold links of its own: HTML doesn't nest them).
    const source =
      this.contentTarget instanceof HTMLTemplateElement
        ? this.contentTarget.content.firstElementChild
        : this.contentTarget
    this.content = source.cloneNode(true)
    this.content.dataset.turboTemporary = true
    if (this.hasContentIdValue) this.content.id = this.contentIdValue
    ;(
      (this.appendToValue && document.querySelector(this.appendToValue)) ||
      document.body
    ).appendChild(this.content)
    Object.assign(this.content.style, {
      position: 'absolute',
      display: 'block',
      left: 0,
      top: 0,
    })

    this.computePosition(true)
    this.cleanup = autoUpdate(
      this.toggleTarget,
      this.content,
      this.computePosition.bind(this, false),
      {
        elementResize: this.updateOnResizeValue,
      }
    )
    addLayer(this, () => this.close())
    document.addEventListener('click', this.closeOnOutsideClick)
    document.addEventListener('hcb:close-menus', this.closeOnRequest)
  }

  /**
   * @param {Event} e
   */
  close(e) {
    if (e && e.currentTarget == document) {
      // Is the clicked element part of the toggle?
      if (e.type == 'click' && this.toggleTarget.contains(e.target)) return
      if (
        e.target == this.content ||
        (this.content?.contains(e.target) &&
          !e.target.dataset?.action?.includes('menu#close'))
      )
        return
      if (
        e.target.tagName.toLowerCase() == 'input' &&
        e.target.closest('.menu__content')
      )
        return
    }

    // Closed with Escape (or anything but a click) while focus was in it:
    // the menu is about to go, so focus goes back to its toggle, not <body>
    if (
      e?.type != 'click' &&
      this.content?.contains(document.activeElement) &&
      this.hasToggleTarget
    )
      this.toggleTarget.focus({ preventScroll: true })

    if (this.content) {
      const content = this.content
      if (e?.type == 'click' && content.contains(e.target)) {
        // let turbo resolve the target frame before removing the link
        content.style.display = 'none'
        setTimeout(() => content.remove(), 0)
      } else {
        // Out the way it came in, like a modal
        content.style.pointerEvents = 'none'
        content.style.transition = 'opacity 0.15s ease, transform 0.15s ease'
        content.style.opacity = '0'

        gsap.to(content, {
          ...this.hidden,
          duration: 0.15,
          overwrite: true,
          onComplete: () => content.remove(),
        })
      }
    }

    if (this.hasToggleTarget)
      this.toggleTarget.setAttribute('aria-expanded', false)
    this.cleanup && this.cleanup()

    this.content = undefined
    this.cleanup = undefined

    this.isOpen = false
    removeLayer(this)
    document.removeEventListener('click', this.closeOnOutsideClick)
    document.removeEventListener('hcb:close-menus', this.closeOnRequest)
  }

  computePosition(firstTime = false) {
    const content = this.content
    if (!content) return

    computePosition(this.toggleTarget, content, {
      placement: this.placementValue,
      middleware: [
        offset(this.placementValue.includes('top') ? 0 : 10),
        flip({ padding: 4 }),
        size({
          padding: 5,
          apply({ availableHeight, availableWidth, elements }) {
            Object.assign(elements.floating.style, {
              maxHeight: `${availableHeight}px`,
              maxWidth: `${availableWidth}px`,
            })
          },
        }),
      ],
    }).then(({ x, y, placement }) => {
      // Closed, or closed and reopened, while this was being worked out
      if (this.content !== content) return

      Object.assign(content.style, {
        top: `${y}px`,
        left: `${x}px`,
      })
      if (!firstTime) return

      this.hidden = { y: placement.includes('top') ? -12 : 12 }
      gsap.from(content, { ...this.hidden, duration: 0.15 })
      // Once, on opening: autoUpdate repositions on every scroll and resize,
      // and would otherwise pull focus back each time
      content
        .querySelectorAll("[data-behavior~='autofocus']")
        .forEach(input => input.focus())
    })
  }
}

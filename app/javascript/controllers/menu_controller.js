import { Controller } from '@hotwired/stimulus'
import {
  autoUpdate,
  computePosition,
  flip,
  offset,
  size,
} from '@floating-ui/dom'
import $ from 'jquery'
import gsap from 'gsap'

export default class extends Controller {
  static targets = ['toggle', 'content']

  static values = {
    appendTo: String,
    placement: { type: String, default: 'bottom-start' },
    contentId: String,
  }

  initialize() {
    this.isOpen = false
  }

  disconnect() {
    this.cleanup && this.cleanup()
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

    this.content = this.contentTarget.cloneNode(true)
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
        elementResize: false, // See https://github.com/hackclub/hcb/issues/8588
      }
    )
  }

  /**
   * @param {Event} e
   */
  close(e) {
    if (e && e.currentTarget == document) {
      // Is the clicked element part of the toggle?
      if (
        e.type == 'click' &&
        (e.target == this.toggleTarget ||
          $(this.toggleTarget).find(e.target).length)
      )
        return
      if (
        e.target == this.content ||
        ($(this.content).find(e.target).length &&
          !e.target.dataset?.action?.includes('menu#close'))
      )
        return
      if (
        e.target.tagName.toLowerCase() == 'input' &&
        $(e.target).closest('.menu__content').length
      )
        return

      this.content && this.content.remove()
    } else {
      this.content && this.content.remove()
    }

    this.toggleTarget.setAttribute('aria-expanded', false)
    this.cleanup && this.cleanup()

    this.content = undefined
    this.cleanup = undefined

    this.isOpen = false
  }

  keydown(e) {
    if (e.code == 'Escape' && this.isOpen) this.close()
  }

  computePosition(firstTime = false) {
    computePosition(this.toggleTarget, this.content, {
      placement: this.placementValue,
      middleware: [
        offset(5),
        flip({ padding: 5 }),
        size({
          padding: 5,
          apply({ availableHeight, elements }) {
            Object.assign(elements.floating.style, {
              maxHeight: `${availableHeight}px`,
            })
          },
        }),
      ],
    }).then(({ x, y, placement }) => {
      Object.assign(this.content.style, {
        top: `${y}px`,
        left: `${x}px`,
      })
      if (firstTime) {
        // Animate!
        gsap.from(this.content, {
          y: placement.includes('top') ? -15 : 15,
          opacity: 0,
          duration: 0.25,
        })
      }

      this.toggleTarget.setAttribute('aria-expanded', true)
      this.isOpen = true

      this.content
        .querySelectorAll("[data-behavior~='autofocus']")
        .forEach(input => input.focus())
    })
  }
}

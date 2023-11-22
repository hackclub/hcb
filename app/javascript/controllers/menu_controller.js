import { Controller } from '@hotwired/stimulus'
import {
  autoUpdate,
  computePosition,
  flip,
  offset,
  size
} from '@floating-ui/dom'
import $ from 'jquery'
import gsap from 'gsap'

export default class extends Controller {
  static targets = ['toggle', 'content']

  static values = {
    appendTo: String,
    placement: { type: String, default: 'bottom-start' }
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
    this.content = this.contentTarget.cloneNode(true)
    this.content.dataset.turboTemporary = true
    ;(
      (this.appendToValue && document.querySelector(this.appendToValue)) ||
      document.body
    ).appendChild(this.content)
    Object.assign(this.content.style, {
      position: 'absolute',
      display: 'block',
      left: 0,
      top: 0
    })

    this.computePosition(true)
    this.cleanup = autoUpdate(
      this.toggleTarget,
      this.content,
      this.computePosition.bind(this, false)
    )
  }

  close(e) {
    if (e) {
      // Is the clicked element part of the toggle?
      if (
        e.target == this.toggleTarget ||
        $(this.toggleTarget).find(e.target).length
      )
        return
      if (e.target == this.content || $(this.content).find(e.target).length)
        return
      if (
        e.target.tagName.toLowerCase() == 'input' &&
        $(e.target).closest('.menu__content').length
      )
        return

      if (!$(e.target).closest('form').length) {
        this.content && this.content.remove()
      } else {
        this.content &&
          Object.assign(this.content.style, {
            display: 'none'
          })
      }
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
              maxHeight: `${availableHeight}px`
            })
          }
        })
      ]
    }).then(({ x, y, placement }) => {
      Object.assign(this.content.style, {
        top: `${y}px`,
        left: `${x}px`
      })
      if (firstTime) {
        // Animate!
        gsap.from(this.content, {
          y: placement.includes('top') ? -15 : 15,
          opacity: 0,
          duration: 0.25
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

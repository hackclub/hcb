import { Controller } from '@hotwired/stimulus'
import {
  autoUpdate,
  computePosition,
  flip,
  offset,
  size,
} from '@floating-ui/dom'
import gsap from 'gsap'
import csrf from '../common/csrf'
import { appsignal } from '../appsignal'

// One tag picker shared by every row of the ledger. The options are identical
// for all rows, so rendering them per row grows the document by rows × tags.
// The menu is rendered once and re-anchored to whichever "+ Add tag" button was
// clicked; that trigger is the row toggles are addressed to.
export default class extends Controller {
  static targets = ['content']

  disconnect() {
    this.close()
  }

  toggle(event) {
    event.preventDefault()
    const trigger = event.currentTarget
    if (this.trigger === trigger) this.close()
    else this.open(trigger)
  }

  open(trigger) {
    if (this.trigger) this.close()

    this.trigger = trigger
    this.markAppliedTags(this.appliedTagIds(trigger.closest('tr')))
    // Anchored at the origin until `reposition` resolves, so the menu can't
    // flash at the `top: 100%` the stylesheet would otherwise give it.
    Object.assign(this.contentTarget.style, {
      display: 'block',
      left: 0,
      top: 0,
    })
    this.reposition(true)
    this.cleanup = autoUpdate(
      trigger,
      this.contentTarget,
      this.reposition.bind(this, false)
    )
    trigger.setAttribute('aria-expanded', true)
  }

  // Also bound to every document click, including the one that opened the menu,
  // so clicks on the open trigger and inside the menu are left alone.
  close(event) {
    if (!this.trigger) return
    if (
      event?.target instanceof Node &&
      (this.contentTarget.contains(event.target) ||
        this.trigger.contains(event.target))
    )
      return

    this.cleanup?.()
    this.cleanup = null
    this.contentTarget.style.display = 'none'
    this.trigger.setAttribute('aria-expanded', false)
    this.trigger = null
  }

  keydown(event) {
    if (event.code === 'Escape') this.close()
  }

  // The row renders a chip per applied tag.
  appliedTagIds(row) {
    return new Set(
      Array.from(row.querySelectorAll('.tags [data-tag]')).map(
        chip => chip.dataset.tag
      )
    )
  }

  // The toggle response streams the row's chips back as its new full list.
  // Turbo stream actions wrap their content in `<template>`, whose children are
  // only reachable through `.content`.
  appliedTagIdsFromStream(html) {
    const document = new DOMParser().parseFromString(html, 'text/html')
    const chips = Array.from(document.querySelectorAll('template')).flatMap(
      template => Array.from(template.content.querySelectorAll('[data-tag]'))
    )

    return new Set(chips.map(chip => chip.dataset.tag))
  }

  markAppliedTags(applied) {
    this.contentTarget.querySelectorAll('[data-tag-id]').forEach(option => {
      option.querySelector('[data-check]').textContent = applied.has(
        option.dataset.tagId
      )
        ? '✓'
        : ''
    })
  }

  async toggleTag(event) {
    event.preventDefault()
    const trigger = this.trigger
    const hcbCode = encodeURIComponent(trigger.dataset.hcbCode)
    const tagId = encodeURIComponent(event.currentTarget.dataset.tagId)

    try {
      const response = await fetch(`/hcb/${hcbCode}/toggle_tag/${tagId}`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrf(),
          Accept: 'text/vnd.turbo-stream.html',
        },
      })

      // A rejected toggle answers with a redirect to a flash-carrying page,
      // which `fetch` follows into a 200 of HTML. Only a turbo stream means the
      // tag actually changed.
      const isStream = response.headers
        .get('content-type')
        ?.includes('text/vnd.turbo-stream.html')
      if (!response.ok || !isStream) {
        throw new Error(`toggle_tag responded ${response.status}`)
      }

      const stream = await response.text()
      window.Turbo.renderStreamMessage(stream)

      // The stream carries this row's full chip list, so the checkmarks come
      // from it rather than from the row — reading the row here would race
      // Turbo's DOM update and leave the menu a toggle behind. Skipped if the
      // menu has since moved to another row.
      if (this.trigger === trigger) {
        this.markAppliedTags(this.appliedTagIdsFromStream(stream))
      }
    } catch (error) {
      appsignal.sendError(error)
      this.showError()
    }
  }

  showError() {
    const flash = document.createElement('p')
    flash.classList.add('flash', 'error', 'fit', 'mt1', 'mb3')
    flash.textContent = "We couldn't update that tag. Please try again."
    this.contentTarget.prepend(flash)
    setTimeout(() => flash.remove(), 5000)
  }

  // `hcb_codes/_create_tag` reads the owning HCB code out of this field.
  stampCreateTag() {
    document.getElementById('create_tag_hcb_code_id').value =
      this.trigger.dataset.hcbCode
    this.close()
  }

  reposition(animate = false) {
    const trigger = this.trigger
    if (!trigger) return

    computePosition(trigger, this.contentTarget, {
      strategy: 'fixed',
      placement: 'bottom-start',
      middleware: [
        offset(10),
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
    })
      .then(({ x, y, placement }) => {
        if (this.trigger !== trigger) return

        Object.assign(this.contentTarget.style, {
          top: `${y}px`,
          left: `${x}px`,
        })
        if (animate) {
          gsap.from(this.contentTarget, {
            y: placement.includes('top') ? -12 : 12,
            opacity: 0.75,
            duration: 0.15,
          })
        }
      })
      .catch(error => appsignal.sendError(error))
  }
}

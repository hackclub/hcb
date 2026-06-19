import { Controller } from '@hotwired/stimulus'

// Interactive "why funders choose HCB" explorer: a vertical list of value props
// on the left, a detail panel on the right that swaps as you select a prop
// (hover on a fine pointer, click/tap anywhere). Implements the WAI-ARIA tabs
// pattern with roving tabindex + arrow-key navigation. With no JS the markup
// shows every panel stacked, so nothing is hidden.
//
// On desktop it also slowly auto-advances through the props to demonstrate that
// the panel is interactive. That self-demo pauses while the pointer is over the
// component (so reading isn't interrupted) and stops for good the moment the
// user selects anything themselves.
const ADVANCE_MS = 4200
const MAX_CYCLES = 2

export default class extends Controller {
  static targets = ['tab', 'panel']

  connect() {
    this.element.classList.add('is-enhanced')
    this.hover = window.matchMedia('(hover: hover) and (pointer: fine)').matches
    // Auto-rotate only where the panel sits beside the tabs (desktop) and the
    // user hasn't asked to reduce motion; on mobile the panel can be off-screen.
    this.canAuto =
      window.matchMedia('(min-width: 880px)').matches &&
      !window.matchMedia('(prefers-reduced-motion: reduce)').matches
    this.cycles = 0
    this.select(0)

    if (this.canAuto) {
      this.observer = new IntersectionObserver(
        ([entry]) =>
          entry.isIntersecting ? this.startAuto() : this.clearTimer(),
        { threshold: 0.5 }
      )
      this.observer.observe(this.element)
    }
  }

  disconnect() {
    this.observer?.disconnect()
    this.clearTimer()
  }

  // Wired from each tab (click / mouseenter / focus).
  choose(event) {
    const i = Number(event.currentTarget.dataset.index)
    if (event.type === 'mouseenter' && !this.hover) return
    this.stopAuto() // a deliberate selection means they know it's interactive
    this.select(i)
    // On tap (mobile), the panel sits below the tabs — bring it into view so
    // the swapped content isn't off-screen. `nearest` is a no-op on desktop
    // where the panel is already visible beside the tabs.
    if (event.type === 'click' && !this.hover) {
      this.panelTargets[i].scrollIntoView({
        behavior: 'smooth',
        block: 'nearest',
      })
    }
  }

  select(index) {
    this.active = index
    this.tabTargets.forEach((tab, i) => {
      const on = i === index
      tab.setAttribute('aria-selected', on ? 'true' : 'false')
      tab.tabIndex = on ? 0 : -1
      tab.classList.toggle('is-active', on)
    })
    this.panelTargets.forEach((panel, i) => {
      panel.classList.toggle('is-active', i === index)
      panel.hidden = i !== index
    })
  }

  // Arrow-key navigation across the tablist.
  keydown(event) {
    const last = this.tabTargets.length - 1
    let next = null
    if (event.key === 'ArrowDown' || event.key === 'ArrowRight')
      next = this.active >= last ? 0 : this.active + 1
    else if (event.key === 'ArrowUp' || event.key === 'ArrowLeft')
      next = this.active <= 0 ? last : this.active - 1
    else if (event.key === 'Home') next = 0
    else if (event.key === 'End') next = last
    if (next === null) return
    event.preventDefault()
    this.stopAuto()
    this.select(next)
    this.tabTargets[next].focus()
  }

  // --- auto-rotation -------------------------------------------------------

  startAuto() {
    if (this.timer || this.stopped) return
    this.timer = setInterval(() => {
      if (this.paused) return // pointer is over the component; hold position
      const next = (this.active + 1) % this.tabTargets.length
      this.select(next)
      if (next === 0 && ++this.cycles >= MAX_CYCLES) this.stopAuto()
    }, ADVANCE_MS)
  }

  clearTimer() {
    clearInterval(this.timer)
    this.timer = null
  }

  // Pointer over the component (wired on the root) pauses the rotation.
  hoverIn() {
    this.paused = true
  }

  hoverOut() {
    this.paused = false
  }

  // Permanent: the user has taken control.
  stopAuto() {
    this.stopped = true
    this.clearTimer()
  }
}

import { Controller } from '@hotwired/stimulus'
import { gsap } from 'gsap'

// Interactive "organizations on HCB" portfolio explorer: a vertical rail of real
// recipient organizations on the left, a detail "stage" on the right that swaps
// as you select one (hover on a fine pointer, click/tap anywhere). The last rail
// item is a "wildcard" that reframes the list as a sample — your giving isn't
// limited to these orgs, or even to orgs already on HCB.
//
// Implements the WAI-ARIA tabs pattern with roving tabindex + arrow-key
// navigation, mirroring funders_explorer_controller so the two selectable rails
// on the page behave identically. With no JS the markup shows every panel
// stacked, so nothing is hidden.
//
// On desktop it slowly auto-advances through the *real* orgs (never the wildcard
// CTA) to demonstrate that the stage is interactive. That self-demo pauses while
// the pointer is over the component and stops for good once the user selects
// anything themselves.
const ADVANCE_MS = 4500
const MAX_CYCLES = 1

export default class extends Controller {
  static targets = ['tab', 'panel', 'count']

  connect() {
    this.element.classList.add('is-enhanced')
    this.enhanced = true
    this.hover = window.matchMedia('(hover: hover) and (pointer: fine)').matches
    this.reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    // Auto-rotate only where the stage sits beside the rail (desktop) and the
    // user hasn't asked to reduce motion; on mobile the stage can be off-screen.
    this.canAuto =
      window.matchMedia('(min-width: 880px)').matches && !this.reduce
    this.cycles = 0
    // Rail items the auto-demo cycles through: the real orgs, never the wildcard.
    this.rotatable = this.tabTargets.filter(
      tab => tab.dataset.wildcard !== 'true'
    ).length
    this.select(0, false)

    this.observer = new IntersectionObserver(
      ([entry]) => {
        if (!entry.isIntersecting) return this.clearTimer()
        this.countUp() // count the org total up the first time it scrolls in
        if (this.canAuto) this.startAuto()
      },
      { threshold: 0.5 }
    )
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
    this.clearTimer()
    // Kill any in-flight tweens so their onUpdate can't write to a detached element
    // after the controller goes away (e.g. a Turbo navigation mid-animation).
    this.countTween?.kill()
    gsap.killTweensOf(this.panelTargets)
  }

  // Wired from each rail item (click / mouseenter / focus).
  choose(event) {
    const i = Number(event.currentTarget.dataset.index)
    if (event.type === 'mouseenter' && !this.hover) return
    this.stopAuto() // a deliberate selection means they know it's interactive
    this.select(i, true)
    // On tap (mobile), the stage sits below the rail — bring the swapped panel to the top
    // of the viewport so the change is always visible feedback (`nearest` under-scrolls when
    // a short panel is already partly in view). `scroll-margin-top` clears the header.
    if (event.type === 'click' && !this.hover) {
      this.panelTargets[i].scrollIntoView({
        behavior: 'smooth',
        block: 'start',
      })
    }
  }

  select(index, animate) {
    this.active = index
    this.tabTargets.forEach((tab, i) => {
      const on = i === index
      tab.setAttribute('aria-selected', on ? 'true' : 'false')
      tab.tabIndex = on ? 0 : -1
      tab.classList.toggle('is-active', on)
    })
    // Visibility is driven by the `is-active` class + CSS (not the `hidden` attribute) so that
    // on desktop the inactive panels can overlap the active one in the same grid cell and still
    // reserve the tallest panel's height — keeping the stage a constant height (no layout shift).
    this.panelTargets.forEach((panel, i) => {
      panel.classList.toggle('is-active', i === index)
    })
    // Crossfade the incoming panel in. CSS handles the no-JS / reduced-motion
    // cases (all panels shown, or shown without motion); this is the enhancement.
    if (animate && !this.reduce) {
      gsap.fromTo(
        this.panelTargets[index],
        { opacity: 0, y: 12 },
        { opacity: 1, y: 0, duration: 0.4, ease: 'power2.out' }
      )
    }
  }

  // Arrow-key navigation across the rail.
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
    this.select(next, true)
    this.tabTargets[next].focus()
  }

  // --- count-up ------------------------------------------------------------
  // Animate the "5,200+ organizations" anchor from zero the first time it's
  // seen. The number is server-rendered (live + floored, with a trailing "+"),
  // so we parse the integer out of the DOM and reformat it as we tween.
  countUp() {
    if (!this.hasCountTarget || this.counted) return
    this.counted = true
    const el = this.countTarget
    const raw = el.textContent.trim()
    const target = Number(raw.replace(/[^\d]/g, ''))
    if (!target) return
    const suffix = raw.replace(/[\d,]/g, '') // keep a trailing "+" if present
    if (this.reduce) return // honor reduced motion: leave the final value as-is

    const proxy = { n: 0 }
    this.countTween = gsap.to(proxy, {
      n: target,
      duration: 1.4,
      ease: 'power2.out',
      onUpdate: () => {
        el.textContent = Math.round(proxy.n).toLocaleString('en-US') + suffix
      },
    })
  }

  // --- auto-rotation -------------------------------------------------------

  startAuto() {
    if (this.timer || this.stopped) return
    this.timer = setInterval(() => {
      if (this.paused) return // pointer is over the component; hold position
      const next = (this.active + 1) % this.rotatable
      this.select(next, true)
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

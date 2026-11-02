import { Controller } from '@hotwired/stimulus'
import { gsap } from 'gsap'

// Interactive "organizations on HCB" portfolio explorer: a rail of real recipient organizations
// and a detail "stage" that swaps as you select one (hover on a fine pointer, click/tap anywhere).
// The last rail item is a "wildcard" that reframes the list as a sample — your giving isn't limited
// to these orgs, or even to orgs already on HCB.
//
// Desktop: the rail is a vertical list beside the stage. Below 880px it becomes a horizontal,
// swipeable strip above the active org's card, with position dots beneath it and edge fades driven
// from scroll position; the wildcard is lifted out of the strip into a static CTA (see the view).
//
// Implements the WAI-ARIA tabs pattern with roving tabindex + arrow-key navigation. With no JS the
// markup shows every panel stacked, so nothing is hidden.
//
// On desktop it slowly auto-advances through the *real* orgs (never the wildcard CTA) to show the
// stage is interactive. That self-demo pauses while the pointer is over the component and stops for
// good once the user selects anything themselves.
const ADVANCE_MS = 4500
const MAX_CYCLES = 1

export default class extends Controller {
  static targets = ['rail', 'tab', 'panel', 'count', 'dot']

  connect() {
    this.element.classList.add('is-enhanced')
    this.enhanced = true
    this.hover = window.matchMedia('(hover: hover) and (pointer: fine)').matches
    this.reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    // The 880px breakpoint splits the two layouts: vertical rail beside the stage (desktop) vs the
    // horizontal swipe strip (mobile). Watched live so orientation/auto-rotate track orientation
    // changes (rotating a phone, resizing a window).
    this.desktopMq = window.matchMedia('(min-width: 880px)')
    this.cycles = 0
    // Rail items the auto-demo cycles through: the real orgs, never the wildcard.
    this.rotatable = this.tabTargets.filter(
      tab => tab.dataset.wildcard !== 'true'
    ).length

    this.applyOrientation()
    this.onBreakpoint = () => {
      this.applyOrientation()
      this.updateStrip()
    }
    this.desktopMq.addEventListener('change', this.onBreakpoint)

    this.select(0, false)
    this.updateStrip() // seed the strip's edge-fade state from the initial scroll position

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
    this.desktopMq?.removeEventListener('change', this.onBreakpoint)
    this.clearTimer()
    // Kill any in-flight tweens so their onUpdate can't write to a detached element
    // after the controller goes away (e.g. a Turbo navigation mid-animation).
    this.countTween?.kill()
    gsap.killTweensOf(this.panelTargets)
  }

  // Auto-rotate only where the stage sits beside the rail (desktop) and the user hasn't asked to
  // reduce motion; on mobile the stage can be off-screen. A getter so it tracks live resizes.
  get canAuto() {
    return this.desktopMq.matches && !this.reduce
  }

  // The rail is the tablist: a vertical list on desktop, a horizontal strip on mobile. Keep the
  // declared orientation honest so AT announces the right arrow-key axis (the handler accepts both).
  applyOrientation() {
    if (this.hasRailTarget) {
      this.railTarget.setAttribute(
        'aria-orientation',
        this.desktopMq.matches ? 'vertical' : 'horizontal'
      )
    }
  }

  // Wired from each rail item (click / mouseenter / focus).
  choose(event) {
    const i = Number(event.currentTarget.dataset.index)
    if (event.type === 'mouseenter' && !this.hover) return
    this.stopAuto() // a deliberate selection means they know it's interactive
    this.select(i, true)
    // On tap (mobile) the rail is a horizontal strip sitting just above the stage, so the swapped
    // card already renders in place beneath it (the gsap crossfade is the visible feedback). Only
    // scroll if the card is entirely off-screen — never yank it to the top, which would push the
    // strip the user is swiping out of view.
    if (event.type === 'click' && !this.hover) {
      const rect = this.panelTargets[i].getBoundingClientRect()
      const offscreen = rect.top >= window.innerHeight || rect.bottom <= 0
      if (offscreen) {
        this.panelTargets[i].scrollIntoView({
          behavior: 'smooth',
          block: 'nearest',
        })
      }
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
    // Mobile position dots mirror the selected org; their count also signals how many orgs there
    // are (hidden on desktop). The wildcard has no dot, so selecting it clears them.
    this.dotTargets.forEach((dot, i) =>
      dot.classList.toggle('is-active', i === index)
    )
    // Crossfade the incoming panel in. CSS handles the no-JS / reduced-motion
    // cases (all panels shown, or shown without motion); this is the enhancement.
    if (animate && !this.reduce) {
      gsap.fromTo(
        this.panelTargets[index],
        { opacity: 0, y: 12 },
        { opacity: 1, y: 0, duration: 0.4, ease: 'power2.out' }
      )
    }
    // Keep the selected chip within the horizontal strip on mobile. Guarded by `animate` so it
    // never runs on the initial connect select, and by `!this.hover` so it's mobile-only.
    if (animate && !this.hover) this.revealTab(index)
  }

  // Bring a chip fully into the strip by nudging ONLY the rail's own scrollLeft — never
  // scrollIntoView, which would scroll every ancestor (including the document) and jump the page.
  revealTab(index) {
    const tab = this.tabTargets[index]
    if (!this.hasRailTarget || !tab) return
    const rail = this.railTarget.getBoundingClientRect()
    const chip = tab.getBoundingClientRect()
    const pad = 14 // leave a sliver of the neighbour visible so the strip still reads as scrollable
    if (chip.left < rail.left + pad) {
      this.railTarget.scrollLeft -= rail.left + pad - chip.left
    } else if (chip.right > rail.right - pad) {
      this.railTarget.scrollLeft += chip.right - (rail.right - pad)
    }
  }

  // Arrow-key navigation across the rail. Walks only the *visible* tabs so the wildcard tab —
  // display:none on mobile, where it's replaced by a static CTA — is never a dead stop.
  keydown(event) {
    const tabs = this.tabTargets.filter(tab => tab.offsetParent !== null)
    if (!tabs.length) return
    const last = tabs.length - 1
    const cur = Math.max(0, tabs.indexOf(this.tabTargets[this.active]))
    let next = null
    if (event.key === 'ArrowDown' || event.key === 'ArrowRight')
      next = cur >= last ? 0 : cur + 1
    else if (event.key === 'ArrowUp' || event.key === 'ArrowLeft')
      next = cur <= 0 ? last : cur - 1
    else if (event.key === 'Home') next = 0
    else if (event.key === 'End') next = last
    if (next === null) return
    event.preventDefault()
    this.stopAuto()
    const target = tabs[next]
    this.select(this.tabTargets.indexOf(target), true)
    target.focus()
  }

  // --- horizontal strip (mobile) -------------------------------------------
  // Edge fades are class-driven from real scroll position so a fade only shows where there's more
  // to scroll — never dimming the last card at the end, or a short (1-2 org) non-scrolling strip.
  onScroll() {
    if (this.scrollRaf) return
    this.scrollRaf = requestAnimationFrame(() => {
      this.scrollRaf = null
      this.updateStrip()
    })
  }

  updateStrip() {
    if (!this.hasRailTarget) return
    const rail = this.railTarget
    const max = rail.scrollWidth - rail.clientWidth
    rail.classList.toggle('is-overflowing', max > 1)
    rail.classList.toggle('is-at-start', rail.scrollLeft <= 1)
    rail.classList.toggle('is-at-end', rail.scrollLeft >= max - 1)
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

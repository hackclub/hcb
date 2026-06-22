import { Controller } from '@hotwired/stimulus'
import { gsap } from 'gsap'

// Animates the "capital -> grants" fan-out in the funders hero: a single funder
// source node wired to several recipient organizations, with pulses of capital
// traveling along each wire and each grant row lighting up as its pulse lands.
//
// The wires are drawn in JS (measured from the live DOM) so the layout stays
// responsive. Everything degrades to a sensible static state: with no JS the
// markup already renders the source + rows, and with prefers-reduced-motion we
// draw the wires once and skip the looping motion.
export default class extends Controller {
  static targets = ['svg', 'source', 'grant']

  connect() {
    this.reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    this.wires = []
    this.pulses = []

    this.buildWires()

    this.resizeObserver = new ResizeObserver(() => this.onResize())
    this.resizeObserver.observe(this.element)

    this.layout()
  }

  // On narrow screens CSS hides the wires and stacks the source over the rows,
  // so we skip the fan-out animation and just show the static list.
  isStacked() {
    return getComputedStyle(this.svgTarget).display === 'none'
  }

  layout() {
    if (this.isStacked()) {
      this.intro?.kill()
      this.loop?.kill()
      gsap.set([this.sourceTarget, ...this.grantTargets], {
        clearProps: 'opacity,transform',
      })
      return
    }

    this.drawWires()

    if (this.reduce || this.animated) {
      // Static (reduced motion) or already played: just show the drawn wires.
      this.wires.forEach(rail => gsap.set(rail, { strokeDashoffset: 0 }))
      return
    }

    this.animated = true
    // Defer one frame so first layout is settled before measuring/animating.
    requestAnimationFrame(() => this.animate())
  }

  disconnect() {
    this.resizeObserver?.disconnect()
    this.intro?.kill()
    this.loop?.kill()
    clearTimeout(this.resizeTimer)
  }

  // Create one rail + one pulse <circle> per grant row, once.
  buildWires() {
    const svgNS = 'http://www.w3.org/2000/svg'
    this.grantTargets.forEach(() => {
      const rail = document.createElementNS(svgNS, 'path')
      rail.setAttribute('class', 'mk-flow__rail')
      rail.setAttribute('fill', 'none')

      const pulse = document.createElementNS(svgNS, 'circle')
      pulse.setAttribute('class', 'mk-flow__pulse')
      pulse.setAttribute('r', '4')
      pulse.style.opacity = '0'

      this.svgTarget.appendChild(rail)
      this.svgTarget.appendChild(pulse)
      this.wires.push(rail)
      this.pulses.push(pulse)
    })
  }

  // Measure source + rows and route a smooth horizontal S-curve to each row.
  drawWires() {
    const box = this.element.getBoundingClientRect()
    const w = Math.round(box.width)
    const h = Math.round(box.height)
    this.svgTarget.setAttribute('width', w)
    this.svgTarget.setAttribute('height', h)
    this.svgTarget.setAttribute('viewBox', `0 0 ${w} ${h}`)

    const src = this.sourceTarget.getBoundingClientRect()
    const sx = src.right - box.left
    const sy = src.top + src.height / 2 - box.top

    this.lengths = []
    this.grantTargets.forEach((row, i) => {
      const r = row.getBoundingClientRect()
      const ex = r.left - box.left
      const ey = r.top + r.height / 2 - box.top
      const dx = ex - sx
      const d = `M ${sx} ${sy} C ${sx + dx * 0.55} ${sy}, ${ex - dx * 0.55} ${ey}, ${ex} ${ey}`
      this.wires[i].setAttribute('d', d)
      this.lengths[i] = this.wires[i].getTotalLength()
    })
  }

  animate() {
    // The intro is deferred a frame, so the controller may have disconnected
    // (e.g. a Turbo navigation) before this runs — bail if the targets are gone.
    if (!this.hasSourceTarget || !this.hasSvgTarget) return

    // Intro: source in, rails draw toward the rows, grant rows stagger in.
    this.intro = gsap.timeline()

    this.wires.forEach((rail, i) => {
      const len = this.lengths[i]
      gsap.set(rail, { strokeDasharray: len, strokeDashoffset: len })
    })

    this.intro
      .from(this.sourceTarget, {
        opacity: 0,
        x: -16,
        duration: 0.5,
        ease: 'power2.out',
      })
      .to(
        this.wires,
        {
          strokeDashoffset: 0,
          duration: 0.7,
          ease: 'power2.inOut',
          stagger: 0.08,
        },
        '-=0.2'
      )
      .from(
        this.grantTargets,
        {
          opacity: 0,
          x: 16,
          duration: 0.5,
          ease: 'power2.out',
          stagger: 0.1,
        },
        '-=0.6'
      )
      .add(() => this.startLoop())
  }

  // Looping payment pulses: capital streams down each wire top-to-bottom, then
  // each row "receives" as its pulse lands. The ball and the row's ring flash
  // ride the SAME timeline, so they can never drift apart.
  startLoop() {
    // Launches are spaced so a ball lands before the next one leaves — the
    // rhythm reads as deliberate "land → flash" beats rather than a busy stream.
    const STAGGER = 1.0
    const SPEED = 360 // px/s — fixed so every pulse moves at the same visual pace

    this.loop = gsap.timeline({ repeat: -1, repeatDelay: 1.2 })

    this.grantTargets.forEach((row, i) => {
      const rail = this.wires[i]
      const pulse = this.pulses[i]
      const len = this.lengths[i]
      const travel = gsap.utils.clamp(0.62, 1.0, len / SPEED)
      const proxy = { p: 0 }
      const seg = gsap.timeline()

      seg
        // Launch: fade in at the source instead of popping into existence.
        .set(pulse, { opacity: 0, attr: { r: 4 } }, 0)
        .to(pulse, { opacity: 1, duration: 0.16, ease: 'sine.out' }, 0)
        .to(
          proxy,
          {
            p: 1,
            duration: travel,
            ease: 'power1.inOut',
            onUpdate: () => {
              const pt = rail.getPointAtLength(proxy.p * len)
              pulse.setAttribute('cx', pt.x)
              pulse.setAttribute('cy', pt.y)
            },
          },
          0
        )
        // Arrival: the ball dissolves exactly as it reaches the row...
        .to(
          pulse,
          { opacity: 0, attr: { r: 7 }, duration: 0.2, ease: 'power2.out' },
          travel - 0.18
        )
        // ...and the row's ring flashes in the same instant (same clock as the
        // ball via the --recv variable, so the two stay locked together).
        // immediateRender:false keeps the ring dark until its moment — otherwise
        // every ring would snap on at the start of each loop (a harsh reset).
        .fromTo(
          row,
          { '--recv': 1 },
          {
            '--recv': 0,
            duration: 0.6,
            ease: 'power2.out',
            immediateRender: false,
          },
          travel - 0.04
        )

      this.loop.add(seg, i * STAGGER)
    })
  }

  onResize() {
    clearTimeout(this.resizeTimer)
    this.resizeTimer = setTimeout(() => this.layout(), 150)
  }
}

import { Controller } from '@hotwired/stimulus'
import { gsap } from 'gsap'

// The funders hero "capital -> grants" scene, staged in 2.5D depth.
//
// A perspective stage holds two layers: an atmosphere far behind, and the field
// (wires + source + recipient cards) in front. As the hero scrolls, the layers
// parallax against each other and the scene gently settles, so the diagram reads
// as a deep, lit scene rather than a flat one.
//
// On top of that, capital flows as luminous comets that ride each wire from the
// source and are absorbed by their recipient, which answers with a soft glow
// swell (not a hard flash). The stream runs a few rich cycles, then relaxes to a
// sparse idle so it never competes with the headline copy beside it.
//
// Everything degrades cleanly: with no JS the markup renders the source + rows;
// with prefers-reduced-motion we draw a static, flat diagram and skip all motion;
// on narrow screens CSS stacks it into a plain list and we disable the 3D.
export default class extends Controller {
  static targets = ['scene', 'atmosphere', 'field', 'svg', 'source', 'grant']

  connect() {
    this.reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches

    this.wires = [] // faint base lines connecting the source to each recipient
    this.charges = [] // moving comet streaks (capital in flight)
    this.lengths = []
    this.SPEED = 165 // px/s — fixed so every comet moves at the same visual pace
    this.LAUNCH = 0.62 // s between successive launches (they overlap into a stream)
    this.scroll = 0 // hero exit progress, 0 (in view) -> 1 (scrolled out)

    this.buildLayers()

    this.resizeObserver = new ResizeObserver(() => this.onResize())
    this.resizeObserver.observe(this.element)

    this.start()

    if (!this.reduce) {
      this.onScroll = () => this.handleScroll()
      window.addEventListener('scroll', this.onScroll, { passive: true })
      this.handleScroll()

      // Pause the capital stream when the scene scrolls out of view.
      this.io = new IntersectionObserver(
        entries => this.setVisible(entries[0].isIntersecting),
        { threshold: 0.05 }
      )
      this.io.observe(this.element)
      this.visible = true
    }

    // The first measure can run before the column width and web font settle,
    // which would bake a stale size into the SVG and misplace the wires. Re-measure
    // once things settle (and note a cached fonts.ready can resolve in a microtask,
    // before the intro's first tick — see the introDone guard in start()).
    this.settle = () => {
      if (this.element.isConnected) this.start()
    }
    requestAnimationFrame(() => requestAnimationFrame(this.settle))
    document.fonts?.ready.then(this.settle)
    if (document.readyState !== 'complete') {
      window.addEventListener('load', this.settle, { once: true })
    }

    // Dev-only hook so the scene can be inspected frame-by-frame by seeking the
    // timelines synchronously (rAF is throttled in a backgrounded tab).
    if (window.location.hostname === 'localhost') window.__funflow = this
  }

  disconnect() {
    this.resizeObserver?.disconnect()
    this.io?.disconnect()
    if (this.onScroll) window.removeEventListener('scroll', this.onScroll)
    if (this.settle) window.removeEventListener('load', this.settle)
    if (this.raf) cancelAnimationFrame(this.raf)
    this.intro?.kill()
    this.loop?.kill()
    clearTimeout(this.resizeTimer)
    if (window.__funflow === this) delete window.__funflow
  }

  // On narrow screens CSS hides the wires and stacks the source over the rows,
  // so we skip the fan-out animation and the 3D entirely.
  isStacked() {
    return getComputedStyle(this.svgTarget).display === 'none'
  }

  motionEnabled() {
    return !this.reduce && !this.isStacked()
  }

  // Create one base wire + one comet charge <path> per grant row, once.
  buildLayers() {
    const svgNS = 'http://www.w3.org/2000/svg'
    this.grantTargets.forEach(() => {
      const wire = document.createElementNS(svgNS, 'path')
      wire.setAttribute('class', 'mk-flow__wire')
      wire.setAttribute('fill', 'none')

      const charge = document.createElementNS(svgNS, 'path')
      charge.setAttribute('class', 'mk-flow__charge')
      charge.setAttribute('fill', 'none')
      charge.style.opacity = '0'

      this.svgTarget.appendChild(wire)
      this.svgTarget.appendChild(charge)
      this.wires.push(wire)
      this.charges.push(charge)
    })
  }

  start() {
    if (!this.hasSvgTarget || !this.hasFieldTarget) return

    if (this.isStacked()) {
      this.intro?.kill()
      this.intro = null
      this.loop?.kill()
      this.clearLayerTransforms()
      gsap.set([...this.wires, this.sourceTarget, ...this.grantTargets], {
        clearProps: 'opacity,transform',
      })
      return
    }

    this.measure()

    if (this.reduce) {
      // Reduced motion: a flat, static diagram, everything shown; no stream.
      gsap.set([...this.wires, this.sourceTarget, ...this.grantTargets], {
        clearProps: 'opacity,transform',
      })
      return
    }

    if (this.played) {
      // Re-measure after a resize / settle. Leave the wires alone while the intro
      // is still pending or fading them in. We track introDone rather than
      // isActive() because a freshly built timeline reports isActive() === false
      // until its first tick — and a settle (e.g. cached fonts.ready resolving in
      // a microtask) can fire before that tick, which would wrongly reveal the
      // wires and skip the intro.
      if (this.intro && !this.introDone) return
      gsap.set(this.wires, { opacity: 1 })
      if (this.loop) {
        this.loop.kill()
        this.startLoop()
      }
      this.applyScroll()
      return
    }

    this.played = true
    // A background / prerendered tab throttles rAF, which would freeze the
    // one-shot intro part-way (e.g. wires drawn toward cards that haven't been
    // revealed yet). Skip the intro there and show the finished scene; the loop
    // waits on visibility. Foreground loads (document.hidden === false) play it.
    if (document.hidden) {
      this.rest()
      this.startLoop()
    } else {
      this.buildIntro()
    }
  }

  // The settled scene with no intro: everything shown, no draw-in.
  rest() {
    this.introDone = true
    gsap.set([...this.wires, this.sourceTarget, ...this.grantTargets], {
      clearProps: 'opacity,transform',
    })
  }

  // Measure source + rows in the field's own (untransformed) coordinate space and
  // route a smooth horizontal S-curve to each row. We neutralise the stage
  // transform first so the parallax offset never skews the geometry — the wires
  // then ride inside the field and stay glued to the cards under any transform.
  measure() {
    const sceneT = this.sceneTarget.style.transform
    const fieldT = this.fieldTarget.style.transform
    this.sceneTarget.style.transform = 'none'
    this.fieldTarget.style.transform = 'none'

    const fbox = this.fieldTarget.getBoundingClientRect()
    // No viewBox: the SVG fills the field via CSS (inset: 0) and draws in 1:1
    // pixel user units, so a stale width can never stretch the wires — it just
    // shifts coordinates slightly until the next re-measure corrects them.
    this.svgTarget.setAttribute('width', Math.round(fbox.width))
    this.svgTarget.setAttribute('height', Math.round(fbox.height))

    const src = this.sourceTarget.getBoundingClientRect()
    const sx = src.right - fbox.left
    const sy = src.top + src.height / 2 - fbox.top

    this.lengths = []
    this.grantTargets.forEach((row, i) => {
      const r = row.getBoundingClientRect()
      const ex = r.left - fbox.left
      const ey = r.top + r.height / 2 - fbox.top
      const dx = ex - sx
      const d = `M ${sx} ${sy} C ${sx + dx * 0.55} ${sy}, ${ex - dx * 0.55} ${ey}, ${ex} ${ey}`
      this.wires[i].setAttribute('d', d)
      this.charges[i].setAttribute('d', d)
      this.lengths[i] = this.wires[i].getTotalLength()
    })

    this.sceneTarget.style.transform = sceneT
    this.fieldTarget.style.transform = fieldT
  }

  // Intro: atmosphere fades up, source eases in, recipients rise into place, and
  // only THEN do the wires fade in to connect them, so a wire never appears
  // before its card (and a paused/slow frame still looks intentional). We fade
  // the wires (rather than a stroke draw-in) because a partial opacity can never
  // show a floating, half-drawn, or wrong-direction segment. The capital stream
  // begins once everything is connected.
  buildIntro() {
    if (!this.hasSourceTarget || !this.hasSvgTarget) return

    this.introDone = false
    this.intro = gsap.timeline({
      onComplete: () => {
        this.introDone = true
        this.startLoop()
      },
    })
    this.intro
      .from(this.atmosphereTarget, {
        opacity: 0,
        duration: 0.7,
        ease: 'power1.out',
      })
      .from(
        this.sourceTarget,
        { opacity: 0, x: -18, duration: 0.55, ease: 'power3.out' },
        '-=0.45'
      )
      .from(
        this.grantTargets,
        {
          opacity: 0,
          x: 18,
          duration: 0.55,
          ease: 'power3.out',
          stagger: 0.09,
        },
        '-=0.3'
      )
      .from(
        this.wires,
        { opacity: 0, duration: 0.5, ease: 'power2.out', stagger: 0.06 },
        '-=0.35'
      )
  }

  // Looping current of capital: a comet grows out of the source along each wire
  // and is absorbed by its recipient, which answers with a soft glow swell. The
  // comet, its fade, and the recipient's --recv all ride the SAME segment
  // timeline, so the "land -> swell" beat can never drift apart. After a few rich
  // cycles the stream relaxes to a sparse idle.
  startLoop() {
    this.cycles = 0
    this.loop = gsap.timeline({
      repeat: -1,
      repeatDelay: 1.1,
      onRepeat: () => {
        this.cycles += 1
        if (this.cycles === 3) this.loop.repeatDelay(3.6) // settle into idle
      },
    })

    this.grantTargets.forEach((row, i) => {
      const charge = this.charges[i]
      const len = this.lengths[i]
      // Tail scales with wire length so short wires don't read as fully lit.
      const tail = gsap.utils.clamp(20, 46, len * 0.42)
      const dur = gsap.utils.clamp(0.6, 1.15, len / this.SPEED)

      // A dash of `tail` with a gap longer than the wire = a single moving streak.
      // strokeDashoffset tail -> tail-len walks its head from the source (0) to
      // the recipient (len); the body trails behind it the whole way.
      const seg = gsap.timeline()
      seg
        .set(
          charge,
          {
            strokeDasharray: `${tail} ${len + tail}`,
            strokeDashoffset: tail,
            opacity: 0,
          },
          0
        )
        .to(charge, { opacity: 1, duration: 0.2, ease: 'sine.out' }, 0)
        .to(
          charge,
          { strokeDashoffset: tail - len, duration: dur, ease: 'power1.inOut' },
          0
        )
        // Absorbed at the recipient: the streak dissolves in place as it lands...
        .to(
          charge,
          { opacity: 0, duration: 0.3, ease: 'power1.out' },
          dur - 0.04
        )
        // ...and the recipient swells with a soft glow (see --recv in CSS), a
        // calm acknowledgement rather than a hard flash. immediateRender:false
        // keeps each row dark until its own moment.
        .fromTo(
          row,
          { '--recv': 1 },
          {
            '--recv': 0,
            duration: 1.0,
            ease: 'power2.out',
            immediateRender: false,
          },
          dur - 0.06
        )

      this.loop.add(seg, i * this.LAUNCH)
    })

    if (this.visible === false) this.loop.pause()
  }

  // -------------------------------------------------------- scroll parallax 2.5D

  handleScroll() {
    const b = this.element.getBoundingClientRect()
    // 0 while the scene sits in view; ramps to 1 as it scrolls up and out.
    this.scroll = gsap.utils.clamp(0, 1, -b.top / (b.height * 0.9))
    if (this.rafPending) return
    this.rafPending = true
    this.raf = requestAnimationFrame(() => {
      this.rafPending = false
      this.applyScroll()
    })
  }

  // Layers separate as the hero scrolls away, which is what reads as 2.5D depth.
  // The field (sharp foreground: cards + wires) leads upward, the atmosphere
  // (soft background) lags well behind, and the whole scene fades. The field and
  // atmosphere are children of the scene, so their offsets compose on top of the
  // scene's settle — hence the modest scene value and the larger field value.
  applyScroll() {
    if (!this.motionEnabled()) {
      this.clearLayerTransforms()
      return
    }
    const p = this.scroll
    this.sceneTarget.style.transform = `translateY(${(p * 14).toFixed(1)}px)`
    this.sceneTarget.style.opacity = (1 - p * 0.3).toFixed(3)
    this.atmosphereTarget.style.transform = `translate3d(0px, ${(p * 72).toFixed(1)}px, -320px) scale(1.35)`
    this.fieldTarget.style.transform = `translate3d(0px, ${(p * -34).toFixed(1)}px, 0px)`
  }

  clearLayerTransforms() {
    ;[this.sceneTarget, this.atmosphereTarget, this.fieldTarget].forEach(el => {
      el.style.transform = ''
      el.style.opacity = ''
    })
  }

  setVisible(v) {
    this.visible = v
    if (!this.loop) return
    v && this.motionEnabled() ? this.loop.resume() : this.loop.pause()
  }

  onResize() {
    clearTimeout(this.resizeTimer)
    this.resizeTimer = setTimeout(() => {
      this.start()
      if (!this.reduce) this.handleScroll()
      if (this.loop) {
        this.visible && this.motionEnabled()
          ? this.loop.resume()
          : this.loop.pause()
      }
    }, 150)
  }
}

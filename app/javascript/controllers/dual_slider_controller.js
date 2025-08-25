// app/javascript/controllers/dual_slider_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["min", "max", "track"]
  static values = { min: Number, max: Number, step: Number, gap: Number }

  connect() {
    // defaults
    this.minValue = this.hasMinValue ? this.minValue : 0
    this.maxValue = this.hasMaxValue ? this.maxValue : 100
    this.stepValue = this.hasStepValue ? this.stepValue : 1
    this.gapValue = this.hasGapValue ? this.gapValue : 0

    // ensure inputs reflect global range
    for (const el of [this.minTarget, this.maxTarget]) {
      el.min = this.minValue
      el.max = this.maxValue
      el.step = this.stepValue
    }

    // initialize values if empty
    if (!this.minTarget.value) this.minTarget.value = this.minValue
    if (!this.maxTarget.value) this.maxTarget.value = this.maxValue

    this._sync()
    this._bind()
  }

  _bind() {
    const onInput = () => { this._clamp(); this._sync(); this._emit() }
    this.minTarget.addEventListener("input", onInput)
    this.maxTarget.addEventListener("input", onInput)
  }

  _clamp() {
    const a = Number(this.minTarget.value)
    const b = Number(this.maxTarget.value)
    const minAllowed = this.minValue
    const maxAllowed = this.maxValue
    const gap = this.gapValue

    let lo = Math.max(minAllowed, Math.min(a, b - gap))
    let hi = Math.min(maxAllowed, Math.max(b, lo + gap))

    // if collision after rounding, push the moved thumb appropriately
    if (lo + gap > hi) {
      if (document.activeElement === this.minTarget) lo = hi - gap
      else hi = lo + gap
    }

    this.minTarget.value = lo
    this.maxTarget.value = hi
  }

  _sync() {
    const lo = Number(this.minTarget.value)
    const hi = Number(this.maxTarget.value)

    // outputs (optional)
    if (this.hasMinTarget) this.minTarget.value = lo
    if (this.hasMaxTarget) this.maxTarget.value = hi

    // track fill
    if (this.hasTrackTarget) {
      const p1 = ((lo - this.minValue) / (this.maxValue - this.minValue)) * 100
      const p2 = ((hi - this.minValue) / (this.maxValue - this.minValue)) * 100
      this.trackTarget.style.background = `
        linear-gradient(to right,
          var(--range-bg, #e5e7eb) 0% ${p1}%,
          var(--range-fill, #3b82f6) ${p1}% ${p2}%,
          var(--range-bg, #e5e7eb) ${p2}% 100%)`
    }

    // handle stacking when thumbs overlap visually
    this.minTarget.style.zIndex = lo >= this.maxValue - 1 ? 6 : 5
    this.maxTarget.style.zIndex = 6
  }

  _emit() {
    this.element.dispatchEvent(new CustomEvent("range-change", {
      bubbles: true,
      detail: {
        min: Number(this.minTarget.value),
        max: Number(this.maxTarget.value)
      }
    }))
  }
}

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    min: { type: Number, default: 0 },
    max: { type: Number, default: 100 },
    step: { type: Number, default: 1 },

    low: { type: Number, default: null },
    high: { type: Number, default: null },

    minDistance: { type: Number, default: 1 },
    keyBase: { type: String, default: '' },
  }

  connect() {
    this.value = [
      this.clamp(
        this.lowValue ?? this.minValue,
        this.minValue,
        Math.max(0, this.maxValue - this.minDistanceValue)
      ),
      this.clamp(
        this.highValue ? this.highValue : this.maxValue,
        this.minValue + this.minDistanceValue,
        this.maxValue
      ),
    ]

    this.activeThumb = null
    this.render()
  }

  clamp(n, min, max) {
    return Math.min(max, Math.max(min, n))
  }

  valueToPercent(value) {
    return ((value - this.minValue) * 100) / (this.maxValue - this.minValue)
  }

  percentToValue(percent) {
    const raw =
      this.minValue + (percent / 100) * (this.maxValue - this.minValue)
    const rounded = Math.round(raw / this.stepValue) * this.stepValue
    return this.clamp(rounded, this.minValue, this.maxValue)
  }

  setLo(next) {
    this.value = [
      this.clamp(next, this.minValue, Math.max(0, this.value[1] - this.minDistanceValue)),
      this.value[1],
    ]
    this.render()
  }

  setHi(next) {
    this.value = [
      this.value[0],
      this.clamp(next, this.value[0] + this.minDistanceValue, this.maxValue),
    ]
    this.render()
  }

  handlePointer(e, which) {
    const rect = this.track.getBoundingClientRect()
    const clientX = 'touches' in e ? e.touches[0].clientX : e.clientX
    const percent = this.clamp(
      ((clientX - rect.left) / rect.width) * 100,
      0,
      100
    )
    const raw = this.percentToValue(percent)
    if (which === 'lo') this.setLo(raw)
    else this.setHi(raw)
  }

  onTrackDown = e => {
    e.preventDefault()
    const rect = this.track.getBoundingClientRect()
    const clientX = 'touches' in e ? e.touches[0].clientX : e.clientX
    const percent = this.clamp(
      ((clientX - rect.left) / rect.width) * 100,
      0,
      100
    )
    const raw = this.percentToValue(percent)
    const dLo = Math.abs(raw - this.value[0])
    const dHi = Math.abs(raw - this.value[1])
    const which = (dLo === dHi ? raw < this.value[0] : dLo < dHi) ? 'lo' : 'hi'
    which === 'lo' ? this.setLo(raw) : this.setHi(raw)
    this.activeThumb = which
    document.addEventListener('mousemove', this.onMove)
    document.addEventListener('mouseup', this.onUp)
    document.addEventListener('touchmove', this.onMove, { passive: false })
    document.addEventListener('touchend', this.onUp)
  }

  onThumbDown = which => e => {
    e.preventDefault()
    this.activeThumb = which
    document.addEventListener('mousemove', this.onMove)
    document.addEventListener('mouseup', this.onUp)
    document.addEventListener('touchmove', this.onMove, { passive: false })
    document.addEventListener('touchend', this.onUp)
  }

  onMove = e => {
    if (!this.activeThumb) return
    this.handlePointer(e, this.activeThumb)
  }

  onUp = () => {
    this.activeThumb = null
    document.removeEventListener('mousemove', this.onMove)
    document.removeEventListener('mouseup', this.onUp)
    document.removeEventListener('touchmove', this.onMove)
    document.removeEventListener('touchend', this.onUp)
  }

  onInputChange = which => e => {
    const val = parseInt(e.target.value, 10)
    if (isNaN(val)) return
    if (which === 'lo') this.setLo(val)
    else this.setHi(val)
  }

  render() {
    if (!this.container) {
      this.container = document.createElement('div')
      this.container.className = 'w-full select-none'
      this.container.innerHTML = `
        <div class="range-slider--inputs">
          <div class="flex items-center gap-1">
            <span>$</span>
            <input placeholder="Min" type="number" class="range-slider--input" name="${this.keyBaseValue}_greater_than" />
          </div>
          <div class="flex items-center gap-1">
            <span>$</span>
            <input placeholder="Max" type="number" class="range-slider--input" name="${this.keyBaseValue}_less_than" />
          </div>
        </div>
        <div class="range-slider--track">
          <div class="range-slider--bar"></div>
          <div class="range-slider--range text-blue-600"></div>
          ${[...new Array(2)].map(() => `<button type="button" class="range-slider--thumb text-blue-600"></button>`).join('')}
        </div>`

      this.element.innerHTML = ''

      this.element.appendChild(this.container)
      this.inputs = this.container.querySelectorAll('.range-slider--input')
      this.track = this.container.querySelector('.range-slider--track')
      this.range = this.container.querySelector('.range-slider--range')
      this.thumbs = this.container.querySelectorAll('.range-slider--thumb')

      this.track.addEventListener('mousedown', this.onTrackDown)
      this.track.addEventListener('touchstart', this.onTrackDown)
      this.thumbs[0].addEventListener('mousedown', this.onThumbDown('lo'))
      this.thumbs[0].addEventListener('touchstart', this.onThumbDown('lo'))
      this.thumbs[1].addEventListener('mousedown', this.onThumbDown('hi'))
      this.thumbs[1].addEventListener('touchstart', this.onThumbDown('hi'))
      this.inputs[0].addEventListener('change', this.onInputChange('lo'))
      this.inputs[1].addEventListener('change', this.onInputChange('hi'))
    }

    const [lo, hi] = this.value
    const pctLo = this.valueToPercent(lo)
    const pctHi = this.valueToPercent(hi)

    this.range.style.left = `${pctLo}%`
    this.range.style.width = `${pctHi - pctLo}%`

    this.thumbs[0].style.left = `${pctLo}%`
    this.thumbs[1].style.left = `${pctHi}%`

    this.inputs[0].value = lo
    this.inputs[1].value = hi
  }
}

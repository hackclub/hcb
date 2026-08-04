import { Controller } from '@hotwired/stimulus'
import sparkline from '@fnando/sparkline'

// Draws a small sparkline from inline data (no fetch). Each datapoint is
// `{ date: "YYYY-MM-DD", value: <number> }`. On hover, the headline swaps to
// that day's value and the "today" label swaps to "on <date>", restoring on
// mouse-out. `format` controls the value rendering ("money" = cents → currency,
// else a plain count).
export default class extends Controller {
  static targets = ['graph', 'value', 'period']
  static values = { data: Array, format: { type: String, default: 'money' } }

  connect() {
    this.draw = this.draw.bind(this)
    this.defaultValue = this.hasValueTarget ? this.valueTarget.textContent : null
    this.defaultPeriod = this.hasPeriodTarget ? this.periodTarget.textContent : null
    this.draw()
    window.addEventListener('resize', this.draw)
  }

  disconnect() {
    window.removeEventListener('resize', this.draw)
  }

  draw() {
    const points = this.dataValue
    if (!points || points.length === 0) return

    // Match the SVG's coordinate space to its rendered width so the line spans
    // the full card instead of the static `width` attribute.
    const width = this.graphTarget.getBoundingClientRect().width
    if (width) this.graphTarget.setAttribute('width', width)

    this.graphTarget.innerHTML = ''
    sparkline(this.graphTarget, points, {
      interactive: true,
      onmousemove: (_event, datapoint) => this.showPoint(datapoint),
      onmouseout: () => this.reset(),
    })
  }

  showPoint({ date, value }) {
    if (this.hasValueTarget) this.valueTarget.textContent = this.format(value)
    if (this.hasPeriodTarget) this.periodTarget.textContent = `on ${this.formatDate(date)}`
  }

  reset() {
    if (this.hasValueTarget && this.defaultValue !== null) {
      this.valueTarget.textContent = this.defaultValue
    }
    if (this.hasPeriodTarget && this.defaultPeriod !== null) {
      this.periodTarget.textContent = this.defaultPeriod
    }
  }

  format(value) {
    if (this.formatValue === 'money') {
      return (value / 100).toLocaleString('en-US', {
        style: 'currency',
        currency: 'USD',
      })
    }

    return value.toLocaleString('en-US')
  }

  formatDate(date) {
    // Parse as local midnight so the label doesn't shift a day in negative TZs.
    return new Date(`${date}T00:00:00`).toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    })
  }
}

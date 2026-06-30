/*
  Limits an <input type="number"> to a specified number of decimal places.
*/

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    places: { type: Number, default: 2 },
  }

  connect() {
    this.onPaste = this.sanitizePaste.bind(this)
    this.element.addEventListener('paste', this.onPaste)
  }

  disconnect() {
    this.element.removeEventListener('paste', this.onPaste)
  }

  sanitizePaste(e) {
    const text = (e.clipboardData || window.clipboardData)?.getData('text')
    if (!text) return

    const cleaned = text.replace(/[^0-9.]/g, '')
    if (cleaned === text) return

    e.preventDefault()
    e.target.value = cleaned
    e.target.dispatchEvent(new Event('input'))
    this.truncate(e)
  }

  truncate(e) {
    const split = e.target.value.split('.')

    if (this.placesValue == 0 && split.length == 2) {
      e.target.value = split[0]
      e.target.dispatchEvent(new Event('input'))
    } else if (split.length == 2 && split[1].length > this.placesValue) {
      e.target.value = [split[0], split[1].slice(0, this.placesValue)].join('.')
      e.target.dispatchEvent(new Event('input'))
    }
  }

  pad(e) {
    e.target.value = parseFloat(e.target.value).toFixed(this.placesValue)
  }
}

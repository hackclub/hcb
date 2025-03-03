/*
  Limits an <input type="number"> to a specified number of decimal places.
*/

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    places: { type: Number, default: 2 },
  }

  truncate(e) {
    const split = e.target.value.split('.')

    if (split.length == 2 && split[1].length > this.placesValue) {
      e.target.value = [split[0], split[1].slice(0, this.placesValue)].join('.')
      e.target.dispatchEvent(new Event('input'))
    }
  }

  pad(e) {
    e.target.value = parseFloat(e.target.value).toFixed(this.placesValue)
  }
}

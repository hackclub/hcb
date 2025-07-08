import { Controller } from '@hotwired/stimulus'
import { Sortable, Plugins, Draggable } from '@shopify/draggable'

export default class extends Controller {
  static values = {
    appendTo: String,
    handle: String,
  }

  connect() {
    this.sortable = new Sortable(this.element, {
      draggable: '.draggable',
      handle: this.handleValue,
      mirror: {
        constrainDimensions: true,
        appendTo: this.appendToValue,
      },
      distance: 10,
      plugins: [Plugins.SortAnimation],
      exclude: {
        sensors: [Draggable.Sensors.TouchSensor],
      },
    })

    this.sortable.on('sortable:sorted', e => {
      this.dispatch('sorted', { detail: e })
    })

    this.sortable.on('sortable:stop', e => {
      this.dispatch('stop', { detail: e })
    })
  }

  disconnect() {
    this.sortable.destroy()
  }
}

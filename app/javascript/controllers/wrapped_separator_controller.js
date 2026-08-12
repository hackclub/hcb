import { Controller } from '@hotwired/stimulus'

// Hides the separator in a wrapping flex row once the item that follows it has
// wrapped onto the next line.

export default class extends Controller {
  static targets = ['separator', 'tail']

  connect() {
    this.observer = new ResizeObserver(() => this.#update())
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  #update() {
    if (!this.hasSeparatorTarget || !this.hasTailTarget) return

    const separator = this.separatorTarget.getBoundingClientRect()
    const tail = this.tailTarget.getBoundingClientRect()

    this.separatorTarget.style.visibility =
      tail.left < separator.right ? 'hidden' : ''
  }
}

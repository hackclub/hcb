import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    this.value = this.element.innerText
    this.step = 0

    this.interval = setInterval(() => {
      this.element.innerText = this.generateText()
      this.step++
    }, 100)
  }

  disconnect() {
    // The element can move while it's animating (jquery-modal re-parents a modal
    // as it opens), which disconnects and reconnects this controller. Put the
    // real value back so the next connect animates towards it, not towards
    // whatever scrambled digits were showing.
    if (this.interval) clearInterval(this.interval)
    this.element.innerText = this.value
  }

  generateText() {
    let result = this.value.slice(0, this.step)

    for (let i = 0; i < this.value.length - this.step; i++) {
      result += Math.floor(Math.random() * 10).toString()
    }

    if (this.step == this.value.length && this.interval) {
      clearInterval(this.interval)
    }

    return result
  }
}

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['fade']

  connect() {
    this.scrollable = this.element.querySelector('[class*="overflow-y"]')
    if (!this.scrollable) return

    this.handleScroll = this.updateFade.bind(this)
    this.scrollable.addEventListener('scroll', this.handleScroll)
    this.updateFade()
  }

  disconnect() {
    if (this.scrollable) {
      this.scrollable.removeEventListener('scroll', this.handleScroll)
    }
  }

  updateFade() {
    const { scrollTop, scrollHeight, clientHeight } = this.scrollable
    const atBottom = scrollTop + clientHeight >= scrollHeight - 1
    this.fadeTarget.classList.toggle('opacity-0', atBottom)
  }
}

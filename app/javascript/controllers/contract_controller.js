import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { advancePath: String }
  static targets = ['button', 'outerContainer', 'innerContainer']

  completed() {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = false
    } else {
      window.location.href = this.advancePathValue
    }
  }

  void() {
    window.location.href = '/'
  }

  toggleFullscreen() {
    this.outerContainerTarget.classList.toggle('fixed')
    this.outerContainerTarget.classList.toggle('relative')
    this.outerContainerTarget.classList.toggle('w-screen')
    this.outerContainerTarget.classList.toggle('h-screen')
    this.innerContainerTarget.classList.toggle('max-h-[50vh]')
    this.innerContainerTarget.classList.toggle('md:max-h-[75vh]')
    this.innerContainerTarget.classList.toggle('max-h-screen')
  }
}

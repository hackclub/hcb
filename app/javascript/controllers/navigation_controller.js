import { Controller } from '@hotwired/stimulus'
import { Turbo } from '@hotwired/turbo-rails'

export default class extends Controller {
  navigate({ params: { location, frame } }) {
    const frameElement = frame ? document.getElementById(frame) : null

    if (frameElement) {
      frameElement.src = location
      frameElement.loaded
    } else {
      Turbo.visit(location)
    }
  }
  navigateOnShiftClick(e) {
    if (event.shiftKey) {
      e.preventDefault()
      e.stopImmediatePropagation()
      this.navigate(e)
    }
  }
}

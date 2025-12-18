import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { advancePath: String }

  completed() {
    window.location.href = this.advancePathValue
  }

  void() {
    window.location.href = '/'
  }
}

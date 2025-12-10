import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['doneButton']

  completed() {
    this.doneButtonTarget.removeAttribute('disabled')
  }

  void() {
    window.location.path = '/'
  }
}

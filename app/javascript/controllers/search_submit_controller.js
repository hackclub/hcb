import { Controller } from '@hotwired/stimulus'

// Turbo only marks forms busy on submit, so mirror it for link visits like clearing
export default class extends Controller {
  markBusy() {
    this.element.closest('form')?.setAttribute('aria-busy', 'true')
  }

  unmarkBusy() {
    this.element.closest('form')?.removeAttribute('aria-busy')
  }
}

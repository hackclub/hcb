import { Controller } from '@hotwired/stimulus'
import { debounce } from 'lodash/function'

export default class extends Controller {
  static targets = ['form']

  connect() {
    this.debouncedSubmit = debounce(() => this.form.requestSubmit(), 300)
  }

  submit() {
    this.form.requestSubmit()
  }

  submitDebounced() {
    this.debouncedSubmit()
  }

  reset() {
    this.form.reset()
  }

  keydown(e) {
    if (e.key == 'Escape') {
      // Claimed, so it doesn't also close what's open around it (app/javascript/layers.js)
      e.preventDefault()
      this.reset()
      this.submit()
    }
  }

  /**
   * @returns {HTMLFormElement}
   */
  get form() {
    if (this.hasFormTarget) {
      return this.formTarget
    } else {
      return this.element
    }
  }
}

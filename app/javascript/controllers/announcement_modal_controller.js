/* global $ */

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { blockId: Number }
  static targets = ['input', 'errors']
  static outlets = ['tiptap']

  donationSummary() {
    const parameters = {
      start_date: this.inputTargets.find(t => t.name == 'start_date').value,
      end_date: this.inputTargets.find(t => t.name == 'end_date').value,
    }

    this.tiptapOutlet
      .donationSummary(parameters, this.blockIdValue)
      .then(this.handleErrors.bind(this))
  }

  hcbCode() {
    const parameters = {
      hcb_code: this.inputTarget.value.split('/').at(-1),
    }

    this.tiptapOutlet
      .hcbCode(parameters, this.blockIdValue)
      .then(this.handleErrors.bind(this))
  }

  handleErrors(errors) {
    if (errors) {
      this.errorsTarget.innerText = errors.join('')
      this.errorsTarget.parentElement.classList.remove('hidden')
    } else {
      this.inputTarget.value = ''
      this.errorsTarget.parentElement.classList.add('hidden')
      $.modal.close()
    }
  }
}

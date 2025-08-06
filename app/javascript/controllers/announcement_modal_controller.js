/* global $ */

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { blockId: Number }
  static targets = ['input', 'errors']
  static outlets = ['tiptap']

  donationSummary() {
    const parameters = this.getDateParameters.bind(this)()

    this.tiptapOutlet
      .block(
        'Announcement::Block::DonationSummary',
        parameters,
        this.blockIdValue
      )
      .then(this.handleErrors.bind(this))
  }

  hcbCode() {
    const parameters = {
      hcb_code: this.inputTarget.value.split('/').at(-1),
    }

    this.tiptapOutlet
      .block('Announcement::Block::HcbCode', parameters, this.blockIdValue)
      .then(this.handleErrors.bind(this))
  }

  topMerchants() {
    const parameters = this.getDateParameters.bind(this)()

    this.tiptapOutlet
      .block('Announcement::Block::TopMerchants', parameters, this.blockIdValue)
      .then(this.handleErrors.bind(this))
  }

  topCategories() {
    const parameters = this.getDateParameters.bind(this)()

    this.tiptapOutlet
      .block(
        'Announcement::Block::TopCategories',
        parameters,
        this.blockIdValue
      )
      .then(this.handleErrors.bind(this))
  }

  topTags() {
    const parameters = this.getDateParameters.bind(this)()

    this.tiptapOutlet
      .block('Announcement::Block::TopTags', parameters, this.blockIdValue)
      .then(this.handleErrors.bind(this))
  }

  topUsers() {
    const parameters = this.getDateParameters.bind(this)()

    this.tiptapOutlet
      .block('Announcement::Block::TopUsers', parameters, this.blockIdValue)
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

  getDateParameters() {
    return {
      start_date: this.inputTargets.find(t => t.name == 'start_date').value,
      end_date: this.inputTargets.find(t => t.name == 'end_date').value,
    }
  }
}

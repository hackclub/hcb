import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { blockId: Number }
  static targets = ['input']
  static outlets = ['tiptap']

  donationSummary() {
    const parameters = {
      start_date: this.inputTarget.value,
    }

    this.tiptapOutlet.donationSummary(parameters, this.blockIdValue)
  }

  hcbCode() {
    const parameters = {
      hcb_code: this.inputTarget.value.split('/').at(-1),
    }

    this.tiptapOutlet.hcbCode(parameters, this.blockIdValue)
  }
}

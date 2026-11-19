import { Controller } from '@hotwired/stimulus'
import { openModal } from '../modal'

// Opens its modal once, as soon as it's rendered: `modal ..., open: true`.
// Not on connect, which runs again when a modal moves (app/javascript/modal.js).
export default class extends Controller {
  initialize() {
    openModal(this.element)
  }
}

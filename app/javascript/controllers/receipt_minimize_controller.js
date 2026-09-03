import { Controller } from '@hotwired/stimulus'

// `unexpandReceipt` lives in the Sprockets bundle (app/assets/javascripts/ui.js),
// which jquery-modal also calls into, so it stays a global rather than moving.
export default class extends Controller {
  minimize() {
    window.unexpandReceipt()
  }
}

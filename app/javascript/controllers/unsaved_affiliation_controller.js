import { Controller } from '@hotwired/stimulus'

// Picking an affiliation type without saving should warn on the way out. The
// confirmation lives on a submit button outside this form (`button` is its id),
// so it is stamped on when a type is picked and cleared on cancel or save.
const UNSAVED_AFFILIATION =
  'You have an unsaved affiliation. Are you sure you want to continue?'

export default class extends Controller {
  static values = { button: String }

  pick(event) {
    if (event.target.type !== 'radio') return

    this.button?.setAttribute('data-turbo-confirm', UNSAVED_AFFILIATION)
  }

  clear() {
    this.button?.removeAttribute('data-turbo-confirm')
  }

  get button() {
    return document.getElementById(this.buttonValue)
  }
}

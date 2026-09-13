import { Controller } from '@hotwired/stimulus'

// Keeps a submit button disabled until the user types an exact phrase.
//
// Progressive enhancement only: the button is rendered enabled so the form
// still works without JS, and the server re-checks the phrase. Never rely on
// this as the only guard.
//
//   <form data-controller="type-to-confirm" data-type-to-confirm-phrase-value="PAGE">
//     <input data-type-to-confirm-target="input" data-action="input->type-to-confirm#check">
//     <input type="submit" data-type-to-confirm-target="submit">
//   </form>
export default class extends Controller {
  static targets = ['input', 'submit']
  static values = { phrase: String }

  connect() {
    this.check()
  }

  check() {
    // Fail open if the markup is incomplete: a missing phrase or input target
    // should leave the form usable rather than trapping someone behind a
    // permanently disabled button.
    if (!this.hasInputTarget || !this.phraseValue) {
      this.setDisabled(false)
      return
    }

    this.setDisabled(this.inputTarget.value.trim() !== this.phraseValue)
  }

  setDisabled(disabled) {
    this.submitTargets.forEach(submit => {
      submit.disabled = disabled
    })
  }
}

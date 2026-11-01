import { Controller } from '@hotwired/stimulus'

const TEAM_EMAIL =
  /(team|webmaster|marketing|admin|info|about|support|sales|hello)/

// Discourages inviting a shared team inbox. The address only counts once it has
// been typed in, so a value the browser restores into the field doesn't warn on
// its own.
export default class extends Controller {
  static targets = ['warning']

  check({ target: { value } }) {
    this.warningTarget.hidden = !TEAM_EMAIL.test(value)
  }
}

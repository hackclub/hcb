import { Controller } from '@hotwired/stimulus'

// Small DOM chores that used to sit in inline `onclick` attributes. Acts on the
// `subject` target when there is one, otherwise on the controller element.
export default class extends Controller {
  static targets = ['subject']

  hide() {
    this.subject.style.display = 'none'
  }

  remove() {
    this.subject.remove()
  }

  stop(event) {
    event.stopPropagation()
  }

  get subject() {
    return this.hasSubjectTarget ? this.subjectTarget : this.element
  }
}

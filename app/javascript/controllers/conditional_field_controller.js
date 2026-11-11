import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['trigger', 'section', 'field']
  static values = { showWhen: String, clearOnHide: Boolean }

  connect() {
    this.toggle()
  }

  toggle() {
    const shown = this.triggerTarget.value === this.showWhenValue

    this.sectionTargets.forEach(section => (section.hidden = !shown))
    this.fieldTargets.forEach(field => {
      field.required = shown
      if (!shown && this.clearOnHideValue) field.value = ''
    })
  }
}

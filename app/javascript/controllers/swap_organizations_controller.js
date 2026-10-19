import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['combobox']

  swap() {
    const [from, to] = this.comboboxTargets.map(el =>
      this.application.getControllerForElementAndIdentifier(el, 'combobox')
    )
    if (!from || !to) return

    const fromOption = from.selectedOption
    const toOption = to.selectedOption

    toOption ? from.commit(toOption) : from.clear()
    fromOption ? to.commit(fromOption) : to.clear()
  }
}

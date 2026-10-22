import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['combobox', 'button']
  static values = {
    disabled: Boolean,
    // Public IDs of the organizations the user can send from. Omitted when
    // they can send from any organization.
    sources: Array,
  }

  connect() {
    this.refresh()
  }

  // Only allow swapping when the "To" organization can become the source.
  refresh() {
    const to = this.comboboxTargets[1]?.dataset.comboboxSelectedValue
    const swappable =
      !to || !this.hasSourcesValue || this.sourcesValue.includes(to)

    this.buttonTarget.disabled = this.disabledValue || !swappable
  }

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

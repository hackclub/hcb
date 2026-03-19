import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['commentableType', 'commentableId']
  static values = {
    privateType: String,
    privateId: String,
    sharedType: String,
    sharedId: String,
  }

  connect() {
    // Find radio buttons within this controller's element
    this.element.addEventListener('change', this.handleChange.bind(this))
  }

  handleChange(event) {
    if (event.target.type !== 'radio') return

    const value = event.target.value
    this.updateHiddenFields(value)
  }

  updateHiddenFields(targetType) {
    if (targetType === 'shared') {
      this.commentableTypeTarget.value = this.sharedTypeValue
      this.commentableIdTarget.value = this.sharedIdValue
    } else {
      this.commentableTypeTarget.value = this.privateTypeValue
      this.commentableIdTarget.value = this.privateIdValue
    }
  }
}

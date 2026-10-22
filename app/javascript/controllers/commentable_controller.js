import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['commentableType', 'commentableId']
  static values = {
    sharedType: String,
    sharedId: String,
  }

  connect() {
    // save initial commentable as the private comment association
    // we need to set it back to this if a user toggles back and forth
    this.privateType = this.commentableTypeTarget.value
    this.privateId = this.commentableIdTarget.value

    // listen for radio buttons
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
      this.commentableTypeTarget.value = this.privateType
      this.commentableIdTarget.value = this.privateId
    }
  }
}

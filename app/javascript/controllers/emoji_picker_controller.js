import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input', 'picker', 'container']

  open = false

  connect() {
    // Lazy load emoji-picker-element only when the controller is first needed
    import('emoji-picker-element').catch(err => {
      console.error('Failed to load emoji-picker-element:', err)
    })
    
    document.addEventListener('click', this.handleDocumentClick.bind(this))
  }

  disconnect() {
    document.removeEventListener('click', this.handleDocumentClick.bind(this))
  }

  validateInput(event) {
    const value = this.inputTarget.value
    const segments = [...new Intl.Segmenter().segment(value)]

    if (
      segments.length > 1 ||
      (value.length > 0 && !value.match(/^\p{Emoji}/u))
    ) {
      const oldValue = value.slice(0, value.length - event.data.length)
      this.inputTarget.value = oldValue
    }
  }

  addEmoji(event) {
    this.inputTarget.value = event.detail.unicode
    this.togglePicker()
  }

  togglePicker() {
    this.open = !this.open
    this.pickerTarget.style = `display: ${this.open ? 'block' : 'none'};`
  }

  handleDocumentClick(event) {
    if (!this.containerTarget.contains(event.target) && this.open == true) {
      this.togglePicker()
    }
  }
}

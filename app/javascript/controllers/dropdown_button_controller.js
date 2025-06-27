import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['text', 'menu', 'container']

  open = false

  connect() {
    document.addEventListener('click', this.handleDocumentClick.bind(this))
  }

  disconnect() {
    document.removeEventListener('click', this.handleDocumentClick.bind(this))
  }

  toggle() {
    this.open = !this.open
    this.updateMenu()
  }

  change(event) {
    const newButtonText = event.target.dataset.label
    this.updateText(newButtonText)
    this.toggle()
  }

  updateText(value) {
    this.textTarget.innerText = value
  }

  updateMenu() {
    this.menuTarget.classList.remove(
      this.open ? 'fade-card-hide' : 'fade-card-show'
    )
    this.menuTarget.classList.add(
      this.open ? 'fade-card-show' : 'fade-card-hide'
    )
  }

  handleDocumentClick(event) {
    if (!this.containerTarget.contains(event.target) && this.open == true) {
      this.toggle()
    }
  }
}

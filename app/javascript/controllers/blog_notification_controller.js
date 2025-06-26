import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['badge', 'widget']

  open = false

  connect() {
    this.updateBadge()
    document.addEventListener('click', this.handleDocumentClick.bind(this))
  }

  disconnect() {
    document.removeEventListener('click', this.handleDocumentClick.bind(this))
  }

  async updateBadge() {
    try {
      const { count } = await fetch(
        'https://blog.hcb.hackclub.com/api/unreads',
        {
          credentials: 'include',
        }
      ).then(res => res.json())

      if (count < 1) return

      this.badgeTarget.innerText = count
      this.badgeTarget.classList.remove('hidden')
    } catch (error) {
      console.error('Error fetching notification count', error)
    }
  }

  toggleWidget(event) {
    event.preventDefault();
    event.stopPropagation()

    if (this.open) {
      this.closeWidget()
    } else {
      this.openWidget()
    }
  }

  openWidget() {
    this.widgetTarget.classList.remove("fade-card-hide")
    this.widgetTarget.classList.add("fade-card-show")
    
    this.open = true;
  }

  closeWidget() {
    this.widgetTarget.classList.remove("fade-card-show")
    this.widgetTarget.classList.add("fade-card-hide")

    this.open = false;
  }

  keydown(e) {
    if (e.code == 'Escape' && this.open) this.closeWidget()
  }

  handleDocumentClick(event) {
    if (!this.widgetTarget.contains(event.target) && this.open == true) {
      this.closeWidget()
    }
  }
}

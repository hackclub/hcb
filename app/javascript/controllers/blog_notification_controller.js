import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['badge']

  connect() {
    this.updateBadge()
  }

  async updateBadge() {
    try {
      const { count } = await fetch('https://blog.hcb.hackclub.com', {
        credentials: 'include',
      }).then(res => res.json())
  
      if (count < 1) return
  
      this.badgeTarget.innerText = count
      this.badgeTarget.classList.remove('hidden')
    } catch (error) {
      console.error('Error fetching notification count', error)
    }
  }
}

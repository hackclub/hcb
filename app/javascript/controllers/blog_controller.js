import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['badge']

  connect() {
    this.updateBadge()
  }

  async updateBadge() {
    try {
      const url =
        window.location.hostname === 'localhost'
          ? 'http://localhost:3001'
          : 'https://blog.hcb.hackclub.com'
      const { count } = await fetch(`${url}/api/unreads`, {
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

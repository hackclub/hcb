import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['badge']

  connect() {
    console.log('BlogNotificationController connected')
    this.updateBadge()
  }

  async updateBadge () {
    const { count } = await fetch("https://blog.hcb.hackclub.com", {
      credentials: "include"
    }).then(res => res.json())

    if (count < 1) return

    this.badgeTarget.innerText = count
    this.badgeTarget.classList.remove('hidden')
  }
}

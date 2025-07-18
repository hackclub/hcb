import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['merchants', 'categories', 'tags', 'users', 'button']

  updateTimeframe(event) {
    const timeframe = event.target.innerText

    this.buttonTarget.innerText = timeframe
    this.merchantsTarget.src = `${this.merchantsTarget.src.split('?')[0]}?timeframe=${timeframe}`
    this.categoriesTarget.src = `${this.categoriesTarget.src.split('?')[0]}?timeframe=${timeframe}`
    this.tagsTarget.src = `${this.tagsTarget.src.split('?')[0]}?timeframe=${timeframe}`
    this.usersTarget.src = `${this.usersTarget.src.split('?')[0]}?timeframe=${timeframe}`
  }
}

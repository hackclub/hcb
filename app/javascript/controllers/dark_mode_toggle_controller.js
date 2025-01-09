/* global getCookie, BK */
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['toggle']

  connect() {
    this.updateActiveCheck()
    this.addClickListeners()
  }

  updateActiveCheck() {
    const selectedTheme = getCookie('theme')
    this.toggleTargets.forEach(target => {
      const check = target.querySelector('svg')
      const targetTheme = target.getAttribute('data-value')
      check?.classList?.[selectedTheme === targetTheme ? 'remove' : 'add']?.(
        'hidden'
      )
    })
  }

  addClickListeners() {
    this.toggleTargets.forEach(target => {
      target.addEventListener('click', () => {
        const selectedTheme = target.getAttribute('data-value')
        BK.setDark(selectedTheme)
        this.updateActiveCheck() // Update the check after changing the theme
      })
    })
  }
}

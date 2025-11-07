/* global getCookie, BK */
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['toggle']

  connect() {
    this.updateActiveCheck()
    this.addClickListeners()
  }

  updateActiveCheck() {
    const selectedTheme = getCookie('theme') || 'system'
    this.updateBlogEmbed(selectedTheme)
    this.toggleTargets.forEach(target => {
      const targetTheme = target.getAttribute('data-value')
      target?.classList?.[selectedTheme === targetTheme ? 'add' : 'remove']?.(
        'hovered',
        'font-bold'
      )
    })
  }

  addClickListeners() {
    this.toggleTargets.forEach(target => {
      target.addEventListener('click', () => {
        const selectedTheme = target.getAttribute('data-value')
        BK.setDark(selectedTheme)
        this.updateActiveCheck() // Update the check after changing the theme
        this.updateBlogEmbed(selectedTheme)
      })
    })
  }

  updateBlogEmbed(theme) {
    const resolvedTheme = theme === 'system' ? BK.resolveSystemTheme() : theme

    const blogEmbed = document.getElementById('blog-widget-embed')
    if (blogEmbed) {
      blogEmbed.src = `${blogEmbed.src.split('?')[0]}?theme=${resolvedTheme}`
    }
  }
}

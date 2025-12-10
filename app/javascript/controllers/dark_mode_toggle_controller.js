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
    this.updateDocusealForm(selectedTheme)
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
        this.updateBlogEmbed(selectedTheme)
        this.updateDocusealForm(selectedTheme)
      })
    })
  }

  updateBlogEmbed(theme) {
    const resolvedTheme = this.resolveTheme(theme)

    const blogEmbed = document.getElementById('blog-widget-embed')
    if (blogEmbed) {
      blogEmbed.src = `${blogEmbed.src.split('?')[0]}?theme=${resolvedTheme}`
    }
  }

  updateDocusealForm(theme) {
    const resolvedTheme = this.resolveTheme(theme)

    const docusealForm = document.getElementById('docusealForm')
    if (docusealForm) {
      if (resolvedTheme == 'dark') {
        docusealForm.setAttribute('data-background-color', '#15151a')
        docusealForm.setAttribute(
          'data-custom-css',
          'label, svg { color: white; }'
        )
      } else {
        docusealForm.removeAttribute('data-background-color')
        docusealForm.removeAttribute('data-custom-css')
      }
    }
  }

  resolveTheme(theme) {
    return theme === 'system' ? BK.resolveSystemTheme() : theme
  }
}

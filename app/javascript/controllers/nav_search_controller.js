import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input', 'frame', 'extraLinks', 'extraLinksDivider']

  connect() {
    this.handleGlobalKeydown = this.handleGlobalKeydown.bind(this)
    document.addEventListener('keydown', this.handleGlobalKeydown)
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleGlobalKeydown)
  }

  handleGlobalKeydown(event) {
    if (event.key === '?' && !this.isTyping(event.target)) {
      event.preventDefault()
      this.inputTarget.focus()
      this.inputTarget.select()
    }
  }

  isTyping(target) {
    return (
      target.tagName === 'INPUT' ||
      target.tagName === 'TEXTAREA' ||
      target.tagName === 'SELECT' ||
      target.isContentEditable
    )
  }

  handleKeydown(event) {
    if (event.key === 'Escape') this.close()
  }

  close() {
    this.inputTarget.value = ''
    this.filter()
    this.inputTarget.blur()
  }

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()

    let anyExtraLinkVisible = false
    this.extraLinksTarget.querySelectorAll('a.dock__item').forEach(item => {
      const matches =
        query === '' || item.textContent.trim().toLowerCase().includes(query)
      item.classList.toggle('hidden', !matches)
      if (matches) anyExtraLinkVisible = true
    })
    this.extraLinksDividerTarget.classList.toggle(
      'hidden',
      !anyExtraLinkVisible
    )

    this.frameTarget.querySelectorAll('details.dock').forEach(detail => {
      let anyVisible = false
      let currentDivider = null
      let dividerHasVisibleItem = false

      Array.from(detail.children).forEach(child => {
        if (child.matches('span.dock__section')) {
          if (currentDivider) {
            currentDivider.classList.toggle('hidden', !dividerHasVisibleItem)
          }
          currentDivider = child
          dividerHasVisibleItem = false
          return
        }

        if (!child.matches('a.dock__item')) return

        const matches =
          query === '' || child.textContent.trim().toLowerCase().includes(query)
        child.classList.toggle('hidden', !matches)
        if (matches) {
          anyVisible = true
          dividerHasVisibleItem = true
        }
      })

      if (currentDivider) {
        currentDivider.classList.toggle('hidden', !dividerHasVisibleItem)
      }

      if (query === '') {
        detail.classList.remove('hidden')
        if (detail.hasAttribute('data-search-open')) {
          detail.removeAttribute('open')
          detail.removeAttribute('data-search-open')
        }
      } else if (anyVisible) {
        detail.classList.remove('hidden')
        if (!detail.hasAttribute('open')) {
          detail.setAttribute('open', '')
          detail.setAttribute('data-search-open', '')
        }
      } else {
        detail.classList.add('hidden')
      }
    })
  }
}

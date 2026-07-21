import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input', 'frame']

  connect() {
    this.handleGlobalKeydown = this.handleGlobalKeydown.bind(this)
    document.addEventListener('keydown', this.handleGlobalKeydown)
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleGlobalKeydown)
  }

  handleGlobalKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'f') {
      event.preventDefault()
      this.inputTarget.focus()
      this.inputTarget.select()
    }
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

    this.frameTarget.querySelectorAll('details.dock').forEach(detail => {
      let anyVisible = false

      detail.querySelectorAll(':scope > a.dock__item').forEach(item => {
        const matches =
          query === '' || item.textContent.trim().toLowerCase().includes(query)
        item.classList.toggle('hidden', !matches)
        if (matches) anyVisible = true
      })

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

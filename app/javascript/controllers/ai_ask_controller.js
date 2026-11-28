import { Controller } from '@hotwired/stimulus'

// "Copy as Markdown" split button. The copy link copies the page's Markdown
// version instead of opening it, and the <details> menu closes on an outside
// click, Escape, or when a link is chosen. Without JS, the link opens the
// Markdown and the menu still opens.
export default class extends Controller {
  static targets = ['copy', 'label', 'menu']

  connect() {
    this.defaultLabel = this.labelTarget.textContent
  }

  disconnect() {
    clearTimeout(this.resetTimer)
  }

  async copy(e) {
    if (!navigator.clipboard) return
    e.preventDefault()

    const url = this.copyTarget.href
    try {
      const fetchMarkdown = () =>
        fetch(url).then(r => {
          if (!r.ok) throw new Error(r.status)
          return r.text()
        })

      if (window.ClipboardItem) {
        // Safari only allows clipboard writes that start inside the click, so it gets the pending fetch.
        const text = fetchMarkdown().then(
          t => new Blob([t], { type: 'text/plain' })
        )
        await navigator.clipboard.write([
          new ClipboardItem({ 'text/plain': text }),
        ])
      } else {
        await navigator.clipboard.writeText(await fetchMarkdown())
      }
      this.confirm()
    } catch {
      window.location.href = url
    }
  }

  confirm() {
    clearTimeout(this.resetTimer)
    // Hold the width so the shorter label doesn't shift the button.
    if (!this.copyTarget.style.minWidth) {
      this.copyTarget.style.minWidth = `${this.copyTarget.offsetWidth}px`
    }
    this.labelTarget.textContent = 'Copied'
    this.copyTarget.classList.add('is-copied')
    this.resetTimer = setTimeout(() => this.reset(), 1500)
  }

  reset() {
    clearTimeout(this.resetTimer)
    this.labelTarget.textContent = this.defaultLabel
    this.copyTarget.classList.remove('is-copied')
    this.copyTarget.style.minWidth = ''
  }

  closeOutside(e) {
    if (!this.element.contains(e.target)) this.close()
  }

  close() {
    this.menuTarget.open = false
  }
}

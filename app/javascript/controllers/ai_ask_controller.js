import { Controller } from '@hotwired/stimulus'

// "Copy as Markdown" split button. The copy link copies the page's Markdown
// version instead of opening it, and the <details> menu closes on an outside
// click or Escape. Without JS, the link opens the Markdown and the menu still opens.
export default class extends Controller {
  static targets = ['copy', 'label', 'menu']

  async copy(e) {
    if (!navigator.clipboard) return
    e.preventDefault()

    const url = this.copyTarget.href
    try {
      if (window.ClipboardItem) {
        // Safari only allows clipboard writes that start inside the click, so it gets the pending fetch.
        const text = fetch(url)
          .then(r => r.text())
          .then(t => new Blob([t], { type: 'text/plain' }))
        await navigator.clipboard.write([
          new ClipboardItem({ 'text/plain': text }),
        ])
      } else {
        await navigator.clipboard.writeText(await (await fetch(url)).text())
      }
      this.confirm()
    } catch {
      window.location.href = url
    }
  }

  confirm() {
    const previous = this.labelTarget.textContent
    // Hold the width so the shorter label doesn't shift the button.
    this.copyTarget.style.minWidth = `${this.copyTarget.offsetWidth}px`
    this.labelTarget.textContent = 'Copied'
    this.copyTarget.classList.add('is-copied')
    setTimeout(() => {
      this.labelTarget.textContent = previous
      this.copyTarget.classList.remove('is-copied')
      this.copyTarget.style.minWidth = ''
    }, 1500)
  }

  closeOutside(e) {
    if (!this.element.contains(e.target)) this.close()
  }

  close() {
    this.menuTarget.open = false
  }
}

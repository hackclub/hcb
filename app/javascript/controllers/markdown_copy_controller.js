import { Controller } from '@hotwired/stimulus'

// On a link to a page's Markdown version: copies the Markdown instead of opening it.
// Without JS, or if the copy fails, the link opens the Markdown as normal.
export default class extends Controller {
  async copy(e) {
    if (!navigator.clipboard) return
    e.preventDefault()

    const url = this.element.href
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
    const previous = this.element.textContent
    this.element.textContent = 'Copied'
    setTimeout(() => (this.element.textContent = previous), 1500)
  }
}

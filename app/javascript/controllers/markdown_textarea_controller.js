import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  paste(e) {
    const textarea = e.target
    const { selectionStart, selectionEnd, value } = textarea

    if (selectionStart === selectionEnd) return

    const pastedText = (e.clipboardData || window.clipboardData).getData('text')

    let url
    try {
      url = new URL(pastedText.trim())
    } catch {
      return
    }

    if (url.protocol !== 'http:' && url.protocol !== 'https:') return

    e.preventDefault()

    const selectedText = value.slice(selectionStart, selectionEnd)
    const markdownLink = `[${selectedText}](${url.href})`

    textarea.setRangeText(markdownLink, selectionStart, selectionEnd, 'end')
    textarea.dispatchEvent(new Event('input', { bubbles: true }))
  }
}

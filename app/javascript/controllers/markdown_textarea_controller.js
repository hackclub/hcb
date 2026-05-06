import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  paste(e) {
    const textarea = e.target
    const { selectionStart, selectionEnd, value } = textarea

    if (selectionStart === selectionEnd) return

    const clipboardData = e.clipboardData || window.clipboardData
    if (!clipboardData) return

    const isLegacyClipboardData = clipboardData === window.clipboardData
    const pastedText = isLegacyClipboardData
      ? clipboardData.getData('URL') || clipboardData.getData('Text')
      : clipboardData.getData('text/uri-list') ||
        clipboardData.getData('text/plain')

    if (!pastedText) return
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

    // execCommand integrates with the browser's native undo stack, unlike setRangeText
    textarea.focus()
    textarea.setSelectionRange(selectionStart, selectionEnd)
    document.execCommand('insertText', false, markdownLink)
    textarea.dispatchEvent(new Event('input', { bubbles: true }))
  }
}

/*
  A lightweight, self-contained autocomplete combobox.

  It loads its options asynchronously from `urlValue` (an endpoint returning
  JSON `[{ value, label, sublabel, disabled }]`), lets the user filter by
  typing, and mirrors the chosen option's `value` into a hidden form field so
  the surrounding form submits it. Only options returned by the endpoint can be
  selected — free text is reverted on blur.
*/

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input', 'hidden', 'listbox']
  static values = {
    url: String,
    selected: String,
    label: String,
  }

  connect() {
    this.options = []
    this.activeIndex = -1
    this.searchToken = 0
    this.deletion = false

    // Restore any preselected value (e.g. when editing or prefilled).
    if (this.selectedValue) {
      this.selectedLabel = this.labelValue
      this.inputTarget.value = this.labelValue
      this.hiddenTarget.value = this.selectedValue
    } else {
      this.selectedLabel = ''
    }
  }

  onFocus() {
    if (this.inputTarget.disabled) return
    this.search(this.query)
  }

  onInput(e) {
    this.deletion = e.inputType && e.inputType.startsWith('delete')
    clearTimeout(this.debounce)
    this.debounce = setTimeout(() => this.search(this.query), 150)
  }

  onKeydown(e) {
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault()
        if (this.isOpen) this.move(1)
        else this.search(this.query)
        break
      case 'ArrowUp':
        e.preventDefault()
        if (this.isOpen) this.move(-1)
        break
      case 'Enter':
        if (this.isOpen && this.activeIndex >= 0) {
          e.preventDefault()
          this.commit(this.options[this.activeIndex])
        }
        break
      case 'Escape':
        if (this.isOpen) {
          e.preventDefault()
          this.hide()
        }
        break
      case 'Tab':
        this.commitOrRevert()
        break
    }
  }

  onBlur() {
    // Delay so a click on an option registers before we tear down.
    setTimeout(() => {
      if (!this.element.contains(document.activeElement)) {
        this.commitOrRevert()
        this.hide()
      }
    }, 150)
  }

  onOptionClick(e) {
    const li = e.target.closest('[role="option"]')
    if (!li || li.getAttribute('aria-disabled') === 'true') return
    this.commit(this.options[Number(li.dataset.index)])
  }

  // --- internals ---

  get query() {
    return this.inputTarget.value.trim()
  }

  get isOpen() {
    return !this.listboxTarget.hasAttribute('hidden')
  }

  async search(query) {
    const token = ++this.searchToken
    let options = []
    try {
      const res = await fetch(this.buildUrl(query), {
        headers: { Accept: 'application/json' },
        credentials: 'same-origin',
      })
      if (res.ok) options = await res.json()
    } catch {
      return
    }
    if (token !== this.searchToken) return // a newer search superseded us

    this.options = options
    this.activeIndex = -1
    this.render()
    this.show()
    if (!this.deletion) this.autocomplete(query)
  }

  buildUrl(query) {
    const sep = this.urlValue.includes('?') ? '&' : '?'
    return `${this.urlValue}${sep}q=${encodeURIComponent(query || '')}`
  }

  // Inline autocomplete: extend the typed text with the first match and select
  // the added portion, so continued typing replaces it.
  autocomplete(query) {
    if (!query) return
    if (this.inputTarget.value.trim().toLowerCase() !== query.toLowerCase())
      return
    const q = query.toLowerCase()
    const match = this.options.find(
      o => !o.disabled && o.label.toLowerCase().startsWith(q)
    )
    if (!match || match.label.toLowerCase() === q) return

    this.inputTarget.value = query + match.label.slice(query.length)
    this.inputTarget.setSelectionRange(query.length, match.label.length)
    this.activeIndex = this.options.indexOf(match)
    this.highlight()
  }

  move(delta) {
    const selectable = this.options
      .map((o, i) => (o.disabled ? -1 : i))
      .filter(i => i >= 0)
    if (selectable.length === 0) return

    const pos = selectable.indexOf(this.activeIndex)
    const next =
      pos === -1
        ? delta > 0
          ? selectable[0]
          : selectable[selectable.length - 1]
        : selectable[(pos + delta + selectable.length) % selectable.length]

    this.activeIndex = next
    this.highlight()
  }

  commit(option) {
    if (!option || option.disabled) return
    this.selectedValue = option.value
    this.selectedLabel = option.label
    this.hiddenTarget.value = option.value
    this.inputTarget.value = option.label
    this.hide()
  }

  // Keep the field valid: accept an exact match, otherwise revert to the last
  // committed selection.
  commitOrRevert() {
    const val = this.query.toLowerCase()
    const match = (this.options || []).find(
      o => !o.disabled && o.label.toLowerCase() === val
    )
    if (match) {
      this.commit(match)
    } else {
      this.inputTarget.value = this.selectedLabel || ''
      this.hiddenTarget.value = this.selectedValue || ''
    }
  }

  render() {
    this.listboxTarget.innerHTML = this.options
      .map((o, i) => {
        const disabled = o.disabled ? ' aria-disabled="true"' : ''
        const dim = o.disabled ? ' opacity-50' : ''
        return `
          <li role="option" data-index="${i}"${disabled}
              class="hw-combobox__option"
              data-action="mousedown->combobox#onOptionClick">
            <div class="flex flex-col w-full${dim}">
              <span style="white-space:normal">${escape(o.label)}</span>
              <span class="text-sm muted">${escape(o.sublabel || '')}</span>
            </div>
          </li>`
      })
      .join('')
    this.highlight()
  }

  highlight() {
    this.listboxTarget.querySelectorAll('[role="option"]').forEach((li, i) => {
      const active = i === this.activeIndex
      li.classList.toggle('hw-combobox__option--navigated', active)
      if (active) li.scrollIntoView({ block: 'nearest' })
    })
  }

  show() {
    this.listboxTarget.removeAttribute('hidden')
    this.inputTarget.setAttribute('aria-expanded', 'true')
  }

  hide() {
    this.listboxTarget.setAttribute('hidden', '')
    this.inputTarget.setAttribute('aria-expanded', 'false')
    this.activeIndex = -1
  }
}

function escape(str) {
  const div = document.createElement('div')
  div.textContent = str
  return div.innerHTML
}

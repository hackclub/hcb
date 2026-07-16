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
      this.selectedOption = {
        value: this.selectedValue,
        label: this.labelValue,
      }
      this.inputTarget.value = this.labelValue
      this.hiddenTarget.value = this.selectedValue
    } else {
      this.selectedLabel = ''
      this.selectedOption = null
    }
  }

  onFocus() {
    if (this.inputTarget.disabled) return
    // With an untouched selection, just show that one option (selected). The
    // full list loads once the user starts typing.
    if (this.query === this.selectedLabel && this.selectedOption) {
      this.inputTarget.select()
      this.options = [this.selectedOption]
      this.activeIndex = 0
      this.render()
      this.show()
    } else {
      this.search(this.query)
    }
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
        this.finalize()
        break
    }
  }

  onBlur() {
    // Delay so a click on an option registers before we tear down.
    setTimeout(() => {
      if (!this.element.contains(document.activeElement)) {
        this.finalize()
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
    this.renderLoading()
    this.show()
    let options = []
    try {
      const res = await fetch(this.buildUrl(query), {
        headers: { Accept: 'application/json' },
        credentials: 'same-origin',
      })
      if (res.ok) options = await res.json()
    } catch {
      if (token === this.searchToken) this.hide()
      return
    }
    if (token !== this.searchToken) return // a newer search superseded us

    this.options = this.withSelected(options)
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

  // Keep the committed selection in the option list so it's shown (and marked)
  // when the list re-opens, even if the current results don't include it.
  withSelected(options) {
    if (!this.selectedValue || !this.selectedOption) return options
    if (options.some(o => o.value === this.selectedValue)) return options
    return [this.selectedOption, ...options]
  }

  commit(option) {
    if (!option || option.disabled) return
    this.selectedValue = option.value
    this.labelValue = option.label
    this.selectedLabel = option.label
    this.selectedOption = option
    this.hiddenTarget.value = option.value
    this.inputTarget.value = option.label
    this.hide()
  }

  // Resolve the field to a valid state when focus leaves:
  //  - an exact match is committed,
  //  - an untouched committed selection is left as-is,
  //  - anything else (e.g. edited/backspaced text) is cleared.
  finalize() {
    const current = this.query
    if (current === '') return this.clear()

    const match = (this.options || []).find(
      o => !o.disabled && o.label.toLowerCase() === current.toLowerCase()
    )
    if (match) return this.commit(match)

    if (current === this.selectedLabel) return // unchanged selection, keep it

    this.clear()
  }

  clear() {
    this.selectedValue = ''
    this.selectedLabel = ''
    this.selectedOption = null
    this.inputTarget.value = ''
    this.hiddenTarget.value = ''
  }

  renderLoading() {
    this.activeIndex = -1
    this.listboxTarget.innerHTML = `
      <li role="option" aria-disabled="true" class="hw-combobox__option">
        <span class="text-sm muted">Loading…</span>
      </li>`
  }

  render() {
    this.listboxTarget.innerHTML = this.options
      .map((o, i) => {
        const disabled = o.disabled ? ' aria-disabled="true"' : ''
        const dim = o.disabled ? ' opacity-50' : ''
        const selected =
          o.value === this.selectedValue ? ' hw-combobox__option--selected' : ''
        return `
          <li role="option" data-index="${i}"${disabled}
              class="hw-combobox__option${selected}"
              data-action="mousedown->combobox#onOptionClick">
            <div class="flex flex-col w-full${dim}">
              <span style="white-space:normal">${escape(o.label)}</span>
              <span class="text-sm muted">${escape(o.sublabel || '')}</span>
            </div>
          </li>`
      })
      .join('')

    // Put the keyboard cursor on the current selection so it's visible.
    const selIdx = this.options.findIndex(
      o => o.value === this.selectedValue && !o.disabled
    )
    if (selIdx >= 0) this.activeIndex = selIdx
    this.highlight()
  }

  highlight() {
    this.listboxTarget.querySelectorAll('[role="option"]').forEach((li, i) => {
      const active = i === this.activeIndex
      li.classList.toggle('hw-combobox__option--navigated', active)
      li.setAttribute('aria-selected', active ? 'true' : 'false')
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

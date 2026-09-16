/*
  A lightweight, self-contained autocomplete combobox. Rendered by
  `ComboboxHelper#combobox_tag`.

  It loads its options asynchronously from `urlValue` — an endpoint called as
  `?q=<query>&page=<n>` and returning JSON `[{ value, label, sublabel,
  disabled }]`, ordered by relevance, where `value` and `label` are required and
  a page with fewer than PAGE_SIZE rows is the last one. The user filters by
  typing, and the chosen option's `value` is mirrored into a hidden form field
  so the surrounding form submits it. Only options returned by the endpoint can
  be selected — free text is reverted on blur.
*/

import { Controller } from '@hotwired/stimulus'

// must equal the value of `PAGE_SIZE` in app/controllers/disbursements_controller.rb
// and app/controllers/admin_controller.rb
const PAGE_SIZE = 25

export default class extends Controller {
  static targets = ['input', 'hidden', 'listbox', 'status']
  static values = {
    url: String,
    selected: String,
    label: String,
  }

  initialize() {
    this.searchToken = 0
  }

  connect() {
    this.options = []
    this.activeIndex = -1
    this.deletion = false
    this.page = 1
    this.hasMore = false
    this.loading = false
    this.currentQuery = ''

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

  disconnect() {
    clearTimeout(this.debounce)
    clearTimeout(this.blurTimeout)
    this.searchToken++ // abandon any search still in flight
  }

  onFocus() {
    if (this.inputTarget.disabled) return
    // With an untouched selection, just show that one option (selected). The
    // full list loads once the user starts typing.
    if (this.query === this.selectedLabel && this.selectedOption) {
      this.inputTarget.select()
      this.options = [this.selectedOption]
      this.hasMore = false
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
    clearTimeout(this.blurTimeout)
    this.blurTimeout = setTimeout(() => {
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

  // Keep the keyboard cursor under the pointer, so clicking always commits the
  // row the user sees highlighted.
  onOptionHover(e) {
    const li = e.target.closest('[role="option"]')
    if (!li || li.getAttribute('aria-disabled') === 'true') return
    const index = Number(li.dataset.index)
    if (index === this.activeIndex) return
    this.activeIndex = index
    this.highlight({ scroll: false })
  }

  // Fetch more results and append when the user scrolls near the bottom.
  onScroll() {
    const el = this.listboxTarget
    if (el.scrollTop + el.clientHeight >= el.scrollHeight - 40) this.loadMore()
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
    this.currentQuery = query
    this.page = 1
    this.renderStatus('Loading…')
    this.show()

    const result = await this.fetchPage(query, 1, token)
    if (!result) return // a newer search superseded us
    if (result.error) return this.renderStatus('Search failed. Try again.')

    this.options = this.withSelected(result.options)
    this.hasMore = result.options.length >= PAGE_SIZE
    this.activeIndex = -1
    this.render()
    this.show()
    if (!this.deletion) this.autocomplete(query)
  }

  async loadMore() {
    if (this.loading || !this.hasMore) return
    const result = await this.fetchPage(
      this.currentQuery,
      this.page + 1,
      this.searchToken
    )
    // On failure keep the rows already on screen rather than replacing them
    // with an error; scrolling again retries.
    if (!result || result.error) return

    this.page += 1
    this.hasMore = result.options.length >= PAGE_SIZE
    const seen = new Set(this.options.map(o => o.value))
    const fresh = result.options.filter(o => !seen.has(o.value))
    const start = this.options.length
    this.options = this.options.concat(fresh)
    this.appendOptions(start)
  }

  // Resolves to `{ options }` on success, `{ error }` on failure, or `null` if
  // a newer search superseded this one. Distinguishing the first two matters:
  // an empty list and a failed request must not look alike to the user.
  async fetchPage(query, page, token) {
    this.loading = true
    try {
      const res = await fetch(this.buildUrl(query, page), {
        headers: { Accept: 'application/json' },
        credentials: 'same-origin',
      })
      if (!res.ok) throw new Error(`Combobox search returned ${res.status}`)
      const options = (await res.json()).map(normalize)
      return token === this.searchToken ? { options } : null
    } catch (error) {
      return token === this.searchToken ? { error } : null
    } finally {
      this.loading = false
    }
  }

  buildUrl(query, page = 1) {
    const sep = this.urlValue.includes('?') ? '&' : '?'
    return `${this.urlValue}${sep}q=${encodeURIComponent(query || '')}&page=${page}`
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

  // Loading/empty/error messages are not choices. Dropping `options` keeps
  // arrow keys from walking (and Enter from committing) the previous search's
  // results while one of these is on screen, and `role="presentation"` keeps
  // screen readers from announcing them as a one-item list — the text goes to
  // the live region instead.
  renderStatus(message) {
    this.options = []
    this.activeIndex = -1
    this.hasMore = false
    this.listboxTarget.innerHTML = `
      <li role="presentation" class="combobox__option combobox__option--status">
        <span class="text-sm muted">${escape(message)}</span>
      </li>`
    this.inputTarget.removeAttribute('aria-activedescendant')
    this.announce(message)
  }

  optionId(index) {
    return `${this.listboxTarget.id}-option-${index}`
  }

  optionHtml(o, i) {
    const disabled = o.disabled ? ' aria-disabled="true"' : ''
    const isSelected = o.value === this.selectedValue
    const selected = isSelected ? ' combobox__option--selected' : ''
    const sublabel = o.sublabel
      ? `<span class="text-sm muted">${escape(o.sublabel)}</span>`
      : ''
    return `
      <li role="option" id="${this.optionId(i)}" data-index="${i}"${disabled}
          aria-selected="${isSelected}"
          class="combobox__option${selected}"
          data-action="mousedown->combobox#onOptionClick mouseover->combobox#onOptionHover">
        <div class="flex flex-col w-full">
          <span>${escape(o.label)}</span>
          ${sublabel}
        </div>
      </li>`
  }

  // Append a page of results without rebuilding the list, preserving scroll.
  appendOptions(start) {
    const html = this.options
      .slice(start)
      .map((o, i) => this.optionHtml(o, start + i))
      .join('')
    this.listboxTarget.insertAdjacentHTML('beforeend', html)
  }

  render() {
    if (this.options.length === 0) return this.renderStatus('No results')

    this.listboxTarget.innerHTML = this.options
      .map((o, i) => this.optionHtml(o, i))
      .join('')

    // Put the keyboard cursor on the current selection so it's visible.
    const selIdx = this.options.findIndex(
      o => o.value === this.selectedValue && !o.disabled
    )
    if (selIdx >= 0) this.activeIndex = selIdx
    this.highlight()
    this.announce(
      `${this.options.length} result${this.options.length === 1 ? '' : 's'}`
    )
  }

  // `aria-selected` marks the committed choice and is set once in `optionHtml`;
  // the keyboard cursor is exposed separately, via `aria-activedescendant`.
  highlight({ scroll = true } = {}) {
    this.listboxTarget.querySelectorAll('[role="option"]').forEach((li, i) => {
      const navigated = i === this.activeIndex
      li.classList.toggle('combobox__option--navigated', navigated)
      if (navigated && scroll) li.scrollIntoView({ block: 'nearest' })
    })

    if (this.activeIndex >= 0 && this.options[this.activeIndex]) {
      this.inputTarget.setAttribute(
        'aria-activedescendant',
        this.optionId(this.activeIndex)
      )
    } else {
      this.inputTarget.removeAttribute('aria-activedescendant')
    }
  }

  announce(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }

  show() {
    this.listboxTarget.removeAttribute('hidden')
    this.inputTarget.setAttribute('aria-expanded', 'true')
  }

  hide() {
    this.listboxTarget.setAttribute('hidden', '')
    this.inputTarget.setAttribute('aria-expanded', 'false')
    this.inputTarget.removeAttribute('aria-activedescendant')
    this.activeIndex = -1
  }
}

function normalize(option) {
  return {
    ...option,
    value: String(option.value ?? ''),
    label: String(option.label ?? ''),
  }
}

function escape(str) {
  const div = document.createElement('div')
  div.textContent = str == null ? '' : str
  return div.innerHTML
}

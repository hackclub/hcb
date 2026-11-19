// Autocomplete combobox rendered by `ComboboxHelper#combobox_tag`. Searches
// `urlValue` (`?q=&page=`, returning `[{ value, label, sublabel, badge, disabled }]`
// in relevance order) and mirrors the chosen value into a hidden field.

import { Controller } from '@hotwired/stimulus'

// must equal the value of `PAGE_SIZE` in app/controllers/concerns/combobox_searchable.rb
const PAGE_SIZE = 25

export default class extends Controller {
  static targets = ['input', 'hidden', 'listbox', 'status', 'badge']
  static values = {
    url: String,
    selected: String,
    label: String,
    badge: String,
  }

  initialize() {
    this.searchToken = 0
    this.requestId = 0
  }

  connect() {
    this.options = []
    this.activeIndex = -1
    this.noFill = false
    this.page = 1
    this.hasMore = false
    this.loading = false
    this.currentQuery = ''

    if (this.selectedValue) {
      this.selectedLabel = this.labelValue
      this.selectedOption = {
        value: this.selectedValue,
        label: this.labelValue,
        badge: this.badgeValue,
      }
      this.inputTarget.value = this.labelValue
      this.hiddenTarget.value = this.selectedValue
    } else {
      this.selectedLabel = ''
      this.selectedOption = null
    }
    this.renderBadge()

    // Capture phase so it runs before Turbo serializes the form.
    this.form = this.element.closest('form')
    this.onFormSubmit = () => this.finalize()
    this.form?.addEventListener('submit', this.onFormSubmit, true)

    this.onBeforeCache = () => this.hide()
    document.addEventListener('turbo:before-cache', this.onBeforeCache)
  }

  disconnect() {
    this.form?.removeEventListener('submit', this.onFormSubmit, true)
    document.removeEventListener('turbo:before-cache', this.onBeforeCache)
    clearTimeout(this.debounce)
    clearTimeout(this.blurTimeout)
    this.debounce = null
    this.pending = false
    this.afterSearch = null
    this.searchToken++
  }

  onFocus() {
    if (this.inputTarget.disabled) return
    clearTimeout(this.blurTimeout)
    this.afterSearch = null
    this.open()
  }

  // Already-focused fields don't get `focus` again.
  onClick() {
    if (!this.inputTarget.disabled && !this.isOpen) this.open()
  }

  // The chevron and padding sit outside the <input>.
  onFieldMousedown(e) {
    if (e.target === this.inputTarget || this.inputTarget.disabled) return
    e.preventDefault()
    if (document.activeElement !== this.inputTarget) {
      this.inputTarget.focus()
    } else if (this.isOpen) {
      this.hide()
    } else {
      this.open()
    }
  }

  // Keep focus in the input when pressing rows or the scrollbar.
  onListboxMousedown(e) {
    e.preventDefault()
  }

  onInput(e) {
    this.noFill =
      e.isComposing ||
      e.inputType === 'insertCompositionText' ||
      Boolean(e.inputType?.startsWith('delete'))
    this.renderBadge()
    this.dismissed = false
    this.pending = true
    this.hiddenTarget.value =
      this.query === this.selectedLabel ? this.selectedValue : ''
    this.filterShown()
    clearTimeout(this.debounce)
    this.debounce = setTimeout(() => {
      this.debounce = null
      this.search(this.query)
    }, 150)
  }

  onKeydown(e) {
    if (e.isComposing || e.keyCode === 229) return
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault()
        if (this.isOpen) this.move(1)
        else this.open()
        break
      case 'ArrowUp':
        e.preventDefault()
        if (this.isOpen) this.move(-1)
        break
      case 'Enter':
        if (this.pending) {
          e.preventDefault()
          this.afterSearch = 'enter'
        } else if (this.isOpen) {
          e.preventDefault()
          this.resolve('enter')
        } else {
          this.finalize()
        }
        break
      case 'Escape':
        if (this.isOpen) {
          e.preventDefault()
          this.hide()
        }
        break
      case 'Tab':
        if (this.pending) this.afterSearch = 'tab'
        else this.resolve('tab')
        break
    }
  }

  onBlur() {
    clearTimeout(this.blurTimeout)
    this.blurTimeout = setTimeout(() => {
      if (this.element.contains(document.activeElement)) return
      if (this.pending) {
        this.afterSearch ||= 'blur'
        // Not `hide()`: that drops the row a deferred Tab will pick.
        this.listboxTarget.setAttribute('hidden', '')
        this.inputTarget.setAttribute('aria-expanded', 'false')
        return
      }
      this.resolve('blur')
      this.hide()
    }, 150)
  }

  onOptionClick(e) {
    const index = this.optionIndexFrom(e)
    if (index >= 0) this.commit(this.options[index])
  }

  // Ignore the `mouseover` browsers fire when rows scroll under a still pointer.
  onOptionHover(e) {
    const moved = e.clientX !== this.pointerX || e.clientY !== this.pointerY
    this.pointerX = e.clientX
    this.pointerY = e.clientY
    if (!moved) return
    const index = this.optionIndexFrom(e)
    if (index < 0 || index === this.activeIndex) return
    this.activeIndex = index
    this.highlight({ scroll: false })
  }

  onScroll() {
    const el = this.listboxTarget
    if (el.scrollTop + el.clientHeight >= el.scrollHeight - 40) this.loadMore()
  }

  get query() {
    return this.inputTarget.value.trim()
  }

  get isOpen() {
    return !this.listboxTarget.hasAttribute('hidden')
  }

  optionIndexFrom(e) {
    const li = e.target.closest('[role="option"]')
    if (!li || li.getAttribute('aria-disabled') === 'true') return -1
    return Number(li.dataset.index)
  }

  open() {
    this.dismissed = false
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

  async search(query) {
    const token = ++this.searchToken
    this.currentQuery = query
    this.page = 1
    this.hasMore = false
    if (this.isOpen && this.listboxTarget.childElementCount > 0) {
      this.listboxTarget.setAttribute('aria-busy', 'true')
    } else {
      this.renderStatus('Loading…')
      if (!this.dismissed) this.show()
    }

    const result = await this.fetchPage(query, 1, token)
    if (!result) return
    this.listboxTarget.removeAttribute('aria-busy')
    if (!this.debounce) this.pending = false

    if (result.error) {
      this.renderStatus('Search failed. Try again.')
    } else {
      this.options = this.withSelected(result.options)
      this.hasMore = result.options.length >= PAGE_SIZE
      this.activeIndex = -1
      this.render()
      if (!query) {
        this.activeIndex = -1
        this.highlight()
      }
      if (!this.dismissed) this.autocomplete(query, result.options)
    }
    if (document.activeElement === this.inputTarget && !this.dismissed)
      this.show()
    if (!this.pending) this.runAfterSearch()
  }

  runAfterSearch() {
    const how = this.afterSearch
    this.afterSearch = null
    if (!how) return
    this.resolve(how)
    if (document.activeElement !== this.inputTarget) this.hide()
  }

  resolve(how) {
    const active = this.options[this.activeIndex]
    const pickable = active && !active.disabled
    if (how === 'enter') {
      if (pickable) this.commit(active)
    } else if (how === 'tab' && pickable && this.query) {
      this.commit(active)
    } else {
      this.finalize()
    }
  }

  async loadMore() {
    if (this.loading || this.pending || !this.hasMore) return
    const result = await this.fetchPage(
      this.currentQuery,
      this.page + 1,
      this.searchToken
    )
    if (!result || result.error) return

    this.page += 1
    this.hasMore = result.options.length >= PAGE_SIZE
    const seen = new Set(this.options.map(o => o.value))
    const fresh = result.options.filter(o => !seen.has(o.value))
    const start = this.options.length
    this.options = this.options.concat(fresh)
    this.appendOptions(start)
  }

  // `null` means a newer search superseded this one.
  async fetchPage(query, page, token) {
    // Only the latest request may clear `loading`, so a superseded one finishing
    // late can't unblock `loadMore` mid-flight and skip a page.
    const request = ++this.requestId
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
      if (request === this.requestId) this.loading = false
    }
  }

  buildUrl(query, page = 1) {
    const sep = this.urlValue.includes('?') ? '&' : '?'
    return `${this.urlValue}${sep}q=${encodeURIComponent(query || '')}&page=${page}`
  }

  // Only ever completes to the top result, so the text matches the highlighted
  // row (e.g. "hq" mustn't complete to "HQ Gas Fund" when "Hack Club HQ" ranks first).
  autocomplete(query, results) {
    if (!query) return
    if (this.query.toLowerCase() !== query.toLowerCase()) return
    const top = results.find(o => !o.disabled)
    if (!top) return

    this.activeIndex = this.options.findIndex(o => o.value === top.value)
    this.highlight()

    const { value, selectionStart, selectionEnd } = this.inputTarget
    if (this.noFill) return
    if (selectionStart !== value.length || selectionEnd !== value.length) return
    const label = top.label
    if (!label.toLowerCase().startsWith(value.toLowerCase())) return
    if (label.length === value.length) return
    // Also runs before a deferred blur resolves, matching what a slower click
    // away would see: the completed text, committed if it's an exact match.
    this.inputTarget.value = label
    if (document.activeElement === this.inputTarget)
      this.inputTarget.setSelectionRange(value.length, label.length)
  }

  move(delta) {
    const rows = this.listboxTarget.querySelectorAll('[role="option"]')
    const selectable = this.options
      .map((o, i) => (o.disabled || rows[i]?.hidden ? -1 : i))
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

  withSelected(options) {
    if (!this.selectedValue || !this.selectedOption) return options
    if (options.some(o => o.value === this.selectedValue)) return options
    return [this.selectedOption, ...options]
  }

  commit(option) {
    if (!option || option.disabled) return
    this.selectedValue = option.value
    this.labelValue = option.label
    this.badgeValue = option.badge ?? ''
    this.selectedLabel = option.label
    this.selectedOption = option
    this.hiddenTarget.value = option.value
    this.inputTarget.value = option.label
    this.hide()
    this.dispatch('change', { detail: { option } })
  }

  finalize() {
    const current = this.query
    if (current === '') return this.clear()
    if (current === this.selectedLabel) {
      this.hiddenTarget.value = this.selectedValue
      this.inputTarget.value = this.selectedLabel
      return
    }

    // Org names aren't unique, so only commit an unambiguous match.
    const matches = (this.options || []).filter(
      o => !o.disabled && o.label.toLowerCase() === current.toLowerCase()
    )
    if (matches.length === 1) return this.commit(matches[0])

    this.clear()
  }

  clear() {
    this.selectedValue = ''
    this.selectedLabel = ''
    this.selectedOption = null
    this.inputTarget.value = ''
    this.hiddenTarget.value = ''
    this.renderBadge()
    this.dispatch('change', { detail: { option: null } })
  }

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
    const selected =
      o.value === this.selectedValue ? ' combobox__option--selected' : ''
    const sublabel = o.sublabel
      ? `<span class="text-sm muted">${escape(o.sublabel)}</span>`
      : ''
    const badge = o.badge
      ? `<code class="combobox__badge">${escape(o.badge)}</code>`
      : ''
    return `
      <li role="option" id="${this.optionId(i)}" data-index="${i}"${disabled}
          aria-selected="false"
          class="combobox__option${selected}"
          data-action="click->combobox#onOptionClick mouseover->combobox#onOptionHover">
        <div class="flex flex-col w-full">
          <div class="flex items-baseline justify-between gap-2">
            <span>${escape(o.label)}</span>
            ${badge}
          </div>
          ${sublabel}
        </div>
      </li>`
  }

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

    const selIdx = this.options.findIndex(
      o => o.value === this.selectedValue && !o.disabled
    )
    if (selIdx >= 0) this.activeIndex = selIdx
    this.highlight()
    this.announce(
      `${this.options.length} result${this.options.length === 1 ? '' : 's'}`
    )
  }

  highlight({ scroll = true } = {}) {
    this.listboxTarget.querySelectorAll('[role="option"]').forEach((li, i) => {
      const navigated = i === this.activeIndex
      li.classList.toggle('combobox__option--navigated', navigated)
      li.setAttribute('aria-selected', String(navigated))
      if (navigated && scroll) this.scrollToRow(li)
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

  scrollToRow(li) {
    const list = this.listboxTarget
    const top = li.offsetTop
    const bottom = top + li.offsetHeight
    if (top < list.scrollTop) list.scrollTop = top
    else if (bottom > list.scrollTop + list.clientHeight)
      list.scrollTop = bottom - list.clientHeight
  }

  filterShown() {
    if (!this.isOpen || this.options.length === 0) return
    const words = this.query.toLowerCase().split(/\s+/).filter(Boolean)
    const rows = this.listboxTarget.querySelectorAll('[role="option"]')
    let first = -1
    rows.forEach((li, i) => {
      const o = this.options[i]
      const text = `${o.label} ${o.sublabel ?? ''}`.toLowerCase()
      li.hidden = !words.every(w => text.includes(w))
      if (!li.hidden && !o.disabled && first < 0) first = i
    })
    if (![...rows].some(li => !li.hidden)) return this.renderStatus('Loading…')
    this.activeIndex = words.length ? first : -1
    this.highlight()
  }

  announce(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }

  renderBadge() {
    const intact = this.inputTarget.value === this.selectedLabel
    this.badgeTarget.textContent = (intact && this.selectedOption?.badge) || ''
  }

  show() {
    if (!this.isOpen) this.place()
    this.listboxTarget.removeAttribute('hidden')
    this.inputTarget.setAttribute('aria-expanded', 'true')
  }

  place() {
    const list = this.listboxTarget
    const gap = 8
    const maxHeight =
      parseFloat(
        getComputedStyle(this.element).getPropertyValue(
          '--combobox-listbox-max-height'
        )
      ) || 250
    const field = this.element.getBoundingClientRect()
    const viewport = window.visualViewport
    const viewTop = viewport ? viewport.offsetTop : 0
    const viewBottom = viewport
      ? viewport.offsetTop + viewport.height
      : window.innerHeight
    const below = viewBottom - field.bottom - gap
    const above = field.top - viewTop - gap

    const up = below < maxHeight && above > below
    list.classList.toggle('combobox__listbox--up', up)
    const room = Math.floor(up ? above : below)
    list.style.maxHeight = `${Math.max(Math.min(maxHeight, room), 96)}px`
  }

  hide() {
    this.dismissed = true
    this.listboxTarget.setAttribute('hidden', '')
    this.inputTarget.setAttribute('aria-expanded', 'false')
    this.inputTarget.removeAttribute('aria-activedescendant')
    this.activeIndex = -1
    this.renderBadge()
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
  div.textContent = str
  return div.innerHTML
}

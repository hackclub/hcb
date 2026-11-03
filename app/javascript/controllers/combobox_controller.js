/*
  A lightweight, self-contained autocomplete combobox. Rendered by
  `ComboboxHelper#combobox_tag`.

  It loads its options asynchronously from `urlValue` — an endpoint called as
  `?q=<query>&page=<n>` and returning JSON `[{ value, label, sublabel, badge,
  disabled }]`, ordered by relevance, where `value` and `label` are required and
  a page with fewer than PAGE_SIZE rows is the last one. The user filters by
  typing, and the chosen option's `value` is mirrored into a hidden form field
  so the surrounding form submits it. Only options returned by the endpoint can
  be selected — free text is reverted on blur.

  The dropdown renders inline at every width. This deliberately drops the
  full-screen `<dialog>` picker the `hotwire_combobox` gem switched to below
  640px: the inline list is usable on a phone and one code path is worth more
  here than the extra mode.
*/

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
  }

  connect() {
    this.options = []
    this.activeIndex = -1
    this.noFill = false
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
        badge: this.badgeValue,
      }
      this.inputTarget.value = this.labelValue
      this.hiddenTarget.value = this.selectedValue
    } else {
      this.selectedLabel = ''
      this.selectedOption = null
    }
    this.renderBadge()

    // Settle the field before its form serializes. A click on Submit lands
    // before the blur handler runs, and would otherwise send whatever the
    // hidden field last held. Capture phase, so it runs before the form's own
    // submit handlers (and Turbo's).
    this.form = this.element.closest('form')
    this.onFormSubmit = () => this.finalize()
    this.form?.addEventListener('submit', this.onFormSubmit, true)

    // Don't let Turbo snapshot the list open: restored from cache, its rows
    // would be dead.
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
    this.searchToken++ // abandon any search still in flight
  }

  onFocus() {
    if (this.inputTarget.disabled) return
    // Back before a blur's deferred settle ran: they're not leaving after all.
    clearTimeout(this.blurTimeout)
    this.afterSearch = null
    this.open()
  }

  // Clicking the field when it already has focus (e.g. right after picking
  // an option) fires no `focus`, so reopen the list here.
  onClick() {
    if (!this.inputTarget.disabled && !this.isOpen) this.open()
  }

  // The chevron and the field's padding sit outside the <input>, so a press
  // there would otherwise do nothing. Treat it as a toggle on the input.
  onFieldMousedown(e) {
    if (e.target === this.inputTarget || this.inputTarget.disabled) return
    e.preventDefault()
    if (document.activeElement !== this.inputTarget) {
      this.inputTarget.focus() // opens via onFocus
    } else if (this.isOpen) {
      this.hide()
    } else {
      this.open()
    }
  }

  // Pressing anywhere in the list (an option, its padding, or the scrollbar)
  // would otherwise move focus off the input, which closes the list mid-drag
  // and breaks keyboard flow after a click.
  onListboxMousedown(e) {
    e.preventDefault()
  }

  onInput(e) {
    // Don't fill in text the user is deleting, or text an IME is still
    // composing (which includes every word on many Android keyboards):
    // rewriting the value mid-composition garbles it.
    this.noFill =
      e.isComposing ||
      e.inputType === 'insertCompositionText' ||
      Boolean(e.inputType?.startsWith('delete'))
    this.renderBadge()
    this.dismissed = false
    this.pending = true
    // The submitted value only stands while the text still reads as it.
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
    // Enter/arrows during IME composition belong to the IME (e.g. confirming
    // a kana conversion), not to the list.
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
        // Results for what's typed haven't arrived yet: the rows on screen are
        // for an older query. Pick from the fresh ones once they land.
        if (this.pending) {
          e.preventDefault()
          this.afterSearch = 'enter'
        } else if (this.isOpen) {
          e.preventDefault()
          this.resolve('enter')
        } else {
          // Closed: make the submitted value match the visible text, then let
          // the form submit.
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
    // Delay so focus moving within the widget (e.g. to the chevron) settles
    // before we tear down.
    clearTimeout(this.blurTimeout)
    this.blurTimeout = setTimeout(() => {
      if (this.element.contains(document.activeElement)) return
      // Let the in-flight search resolve the text, rather than judging it
      // against stale results.
      if (this.pending) {
        this.afterSearch ||= 'blur'
        // Out of the way now, without dropping the cursor the deferred
        // Tab/Enter will pick from.
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

  // Keep the keyboard cursor under the pointer, so clicking always commits the
  // row the user sees highlighted.
  //
  // Only for real pointer movement: when the list scrolls (arrowing down) or
  // re-renders under a resting pointer, browsers fire `mouseover` for whatever
  // row slid underneath, which would yank the cursor back from the keyboard.
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

  // Index of the selectable option an event landed on, or -1.
  optionIndexFrom(e) {
    const li = e.target.closest('[role="option"]')
    if (!li || li.getAttribute('aria-disabled') === 'true') return -1
    return Number(li.dataset.index)
  }

  open() {
    this.dismissed = false
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

  async search(query) {
    const token = ++this.searchToken
    this.currentQuery = query
    this.page = 1
    this.hasMore = false // the rows on screen aren't this query's to page
    // Swapping the rows for "Loading…" on every keystroke makes the list
    // flash and jump. Keep what's on screen until the new rows replace it, and
    // only show the placeholder when there's nothing to show yet.
    if (this.isOpen && this.listboxTarget.childElementCount > 0) {
      this.listboxTarget.setAttribute('aria-busy', 'true')
    } else {
      this.renderStatus('Loading…')
      if (!this.dismissed) this.show()
    }

    const result = await this.fetchPage(query, 1, token)
    if (!result) return // a newer search superseded us
    this.listboxTarget.removeAttribute('aria-busy')
    // Typing since this search started means another is on its way.
    if (!this.debounce) this.pending = false

    if (result.error) {
      this.renderStatus('Search failed. Try again.')
    } else {
      this.options = this.withSelected(result.options)
      this.hasMore = result.options.length >= PAGE_SIZE
      this.activeIndex = -1
      this.render()
      // An emptied field shouldn't quietly re-pick the old selection on Enter.
      if (!query) {
        this.activeIndex = -1
        this.highlight()
      }
      // Closed with Escape or a click while loading: don't touch their text.
      if (!this.dismissed) this.autocomplete(query, result.options)
    }
    if (document.activeElement === this.inputTarget && !this.dismissed)
      this.show()
    if (!this.pending) this.runAfterSearch()
  }

  // Finish an Enter/Tab/blur that arrived while results were still loading.
  runAfterSearch() {
    const how = this.afterSearch
    this.afterSearch = null
    if (!how) return
    this.resolve(how)
    if (document.activeElement !== this.inputTarget) this.hide()
  }

  // Settle the field for the way the user is leaving it:
  //  - enter: pick the highlighted row; with none, leave the text be,
  //  - tab:   pick the highlighted row if they typed something, else finalize,
  //  - blur:  finalize (a click elsewhere isn't a choice of the highlighted row).
  resolve(how) {
    // `hide()` drops the cursor, so a closed list has no active row.
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

  // Put the keyboard cursor on the top result, so Enter picks it. Unless the
  // user is deleting, also fill in the rest of its label after the caret
  // (selected, so continued typing replaces it) when it starts with what was
  // typed.
  //
  // Only the *top* result is considered: results arrive in relevance order, so
  // completing to a lower prefix match (e.g. "hq" → "HQ Gas Fund" when
  // "Hack Club HQ" ranks first) would make the text disagree with the
  // highlighted row. `results` is the server's list, without the previous
  // selection `withSelected` may have prepended.
  autocomplete(query, results) {
    if (!query) return
    if (this.query.toLowerCase() !== query.toLowerCase()) return // typed on
    const top = results.find(o => !o.disabled)
    if (!top) return

    this.activeIndex = this.options.findIndex(o => o.value === top.value)
    this.highlight()

    // Only extend text typed at the end. With the caret mid-text the user is
    // editing, and replacing the value would move the caret out from under them.
    const { value, selectionStart, selectionEnd } = this.inputTarget
    if (this.noFill) return
    if (selectionStart !== value.length || selectionEnd !== value.length) return
    // Against the raw text, so a just-typed trailing space ("hack ") counts.
    const label = top.label
    if (!label.toLowerCase().startsWith(value.toLowerCase())) return
    if (label.length === value.length) return
    // Use the label's own casing, so "hq g" reads "HQ Gas Fund" rather than
    // "hq gas Fund".
    this.inputTarget.value = label
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
    this.badgeValue = option.badge ?? ''
    this.selectedLabel = option.label
    this.selectedOption = option
    this.hiddenTarget.value = option.value
    this.inputTarget.value = option.label
    this.hide()
    this.dispatch('change', { detail: { option } })
  }

  // Resolve the field to a valid state when focus leaves:
  //  - an untouched committed selection is left as-is, even if its label isn't unique,
  //  - an exact match is committed, if it's the only one,
  //  - anything else (e.g. edited/backspaced text) is cleared.
  finalize() {
    const current = this.query
    if (current === '') return this.clear()
    if (current === this.selectedLabel) {
      this.hiddenTarget.value = this.selectedValue
      this.inputTarget.value = this.selectedLabel
      return
    }

    // Names aren't unique: only an unambiguous match is a choice.
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

  // Only show the badge while the field still reads as the selection it belongs to.
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
    const gap = 8 // keep clear of the viewport edge
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
    // Never squeeze it below a couple of rows; past that the page can scroll.
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

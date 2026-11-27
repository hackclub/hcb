// Suggests street addresses while the user types into a form's street address
// field and fills the rest of the address in when they pick one.
//
// Put the controller on an element enclosing the address fields and mark them
// with targets. Only `line1` is required; the others are filled in when present
// and not disabled. `state` and `country` may be `<select>`s or text inputs.
//
//   <div data-controller="address-autocomplete" data-address-autocomplete-country-value="US">
//     <input data-address-autocomplete-target="line1">
//     <input data-address-autocomplete-target="city">
//     <select data-address-autocomplete-target="state">...</select>
//     <input data-address-autocomplete-target="postalCode">
//     <select data-address-autocomplete-target="country">...</select>
//   </div>
//
// Suggestions come from `AddressSuggestionsController` (`?q=&country=`), which
// returns `[{ label, line1, city, state_name, state_code, postal_code, country }]`
// in relevance order. The `country` target's value, when it's a two-letter
// code, restricts the search; otherwise `countryValue` does.

import { Controller } from '@hotwired/stimulus'

const MIN_QUERY_LENGTH = 3
const DEBOUNCE_MS = 250
// Countries whose address forms write the region as a two-letter code
const CODED_REGION_COUNTRIES = ['US', 'CA']

let nextId = 0

export default class extends Controller {
  static targets = ['line1', 'city', 'state', 'postalCode', 'country']
  static values = {
    url: { type: String, default: '/address_suggestions' },
    country: String,
  }

  // Target callbacks run before connect(), so the handlers they bind are set up here
  initialize() {
    this.id = `address_autocomplete_${nextId++}`
    this.onInput = () => this.scheduleSearch()
    this.onKeydown = event => this.keydown(event)
    // Only when focus really left, not on a synthetic blur while still focused
    this.onBlur = event => {
      if (document.activeElement !== event.target) this.hide()
    }
    this.onListboxMousedown = event => event.preventDefault() // keep focus in the input
    this.onListboxClick = event => this.clickOption(event)
    this.onBeforeCache = () => this.hide()
  }

  connect() {
    this.suggestions = []
    this.activeIndex = -1
    document.addEventListener('turbo:before-cache', this.onBeforeCache)
  }

  disconnect() {
    document.removeEventListener('turbo:before-cache', this.onBeforeCache)
    this.cancelSearch()
    this.listbox?.remove()
    this.announcer?.remove()
    this.listbox = null
    this.announcer = null
  }

  line1TargetConnected(input) {
    input.setAttribute('autocomplete', 'off')
    input.setAttribute('role', 'combobox')
    input.setAttribute('aria-autocomplete', 'list')
    input.setAttribute('aria-expanded', 'false')
    input.setAttribute('aria-controls', `${this.id}_listbox`)

    input.addEventListener('input', this.onInput)
    input.addEventListener('keydown', this.onKeydown)
    input.addEventListener('blur', this.onBlur)
  }

  line1TargetDisconnected(input) {
    input.removeEventListener('input', this.onInput)
    input.removeEventListener('keydown', this.onKeydown)
    input.removeEventListener('blur', this.onBlur)
    this.hide()
  }

  // --- searching ---

  scheduleSearch() {
    this.cancelSearch()
    const query = this.line1Target.value.trim()
    if (query.length < MIN_QUERY_LENGTH) {
      this.hide()
      return
    }
    this.debounce = setTimeout(() => this.search(query), DEBOUNCE_MS)
  }

  cancelSearch() {
    clearTimeout(this.debounce)
    this.debounce = null
    this.abortController?.abort()
    this.abortController = null
  }

  async search(query) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set('q', query)
    const country = this.searchCountry()
    if (country) url.searchParams.set('country', country)

    this.abortController = new AbortController()
    let suggestions
    try {
      const response = await fetch(url, {
        headers: { Accept: 'application/json' },
        signal: this.abortController.signal,
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      suggestions = await response.json()
    } catch (error) {
      if (error.name === 'AbortError') return
      this.hide()
      return
    }

    // Ignore a stale response when the field was cleared or the suggestions
    // no longer match what's typed
    if (this.line1Target.value.trim() !== query) return

    this.show(suggestions)
  }

  searchCountry() {
    const selected = this.hasCountryTarget
      ? this.countryTarget.value.trim()
      : ''
    if (/^[A-Za-z]{2}$/.test(selected)) return selected.toUpperCase()
    return this.countryValue || null
  }

  // --- dropdown ---

  show(suggestions) {
    this.suggestions = suggestions
    this.activeIndex = -1

    if (suggestions.length === 0) {
      this.hide()
      return
    }

    const listbox = this.ensureListbox()
    listbox.replaceChildren(
      ...suggestions.map((suggestion, index) => {
        const option = document.createElement('li')
        option.id = `${this.id}_option_${index}`
        option.setAttribute('role', 'option')
        option.setAttribute('aria-selected', 'false')
        option.dataset.index = index
        option.className = 'combobox__option'

        const line1 = document.createElement('span')
        line1.textContent = suggestion.line1
        const detail = document.createElement('span')
        detail.className = 'address-autocomplete__detail'
        detail.textContent = suggestion.label.startsWith(`${suggestion.line1},`)
          ? suggestion.label.slice(suggestion.line1.length + 1).trim()
          : suggestion.label

        option.append(line1, detail)
        return option
      })
    )

    this.position(listbox)
    listbox.hidden = false
    this.line1Target.setAttribute('aria-expanded', 'true')
    this.announce(
      suggestions.length === 1
        ? '1 address suggestion'
        : `${suggestions.length} address suggestions`
    )
  }

  hide() {
    this.cancelSearch()
    this.suggestions = []
    this.activeIndex = -1
    if (this.listbox) this.listbox.hidden = true
    if (this.hasLine1Target) {
      this.line1Target.setAttribute('aria-expanded', 'false')
      this.line1Target.removeAttribute('aria-activedescendant')
    }
  }

  get open() {
    return Boolean(this.listbox) && !this.listbox.hidden
  }

  ensureListbox() {
    const input = this.line1Target
    const anchor = input.parentElement
    anchor.classList.add('address-autocomplete__anchor')

    if (!this.listbox || this.listbox.parentElement !== anchor) {
      this.listbox?.remove()
      this.listbox = document.createElement('ul')
      this.listbox.id = `${this.id}_listbox`
      this.listbox.setAttribute('role', 'listbox')
      this.listbox.setAttribute('aria-label', 'Address suggestions')
      this.listbox.className = 'combobox__listbox address-autocomplete__listbox'
      this.listbox.hidden = true
      this.listbox.addEventListener('mousedown', this.onListboxMousedown)
      this.listbox.addEventListener('click', this.onListboxClick)
      input.insertAdjacentElement('afterend', this.listbox)
    }

    if (!this.announcer) {
      this.announcer = document.createElement('div')
      this.announcer.className = 'combobox__announcer'
      this.announcer.setAttribute('role', 'status')
      this.announcer.setAttribute('aria-live', 'polite')
      this.listbox.insertAdjacentElement('afterend', this.announcer)
    }

    return this.listbox
  }

  // Line the dropdown up under the input, which may share its parent with
  // other fields.
  position(listbox) {
    const input = this.line1Target
    listbox.style.left = `${input.offsetLeft}px`
    listbox.style.top = `${input.offsetTop + input.offsetHeight + 4}px`
    listbox.style.width = `${input.offsetWidth}px`
  }

  announce(message) {
    if (this.announcer) this.announcer.textContent = message
  }

  // --- navigation ---

  keydown(event) {
    switch (event.key) {
      case 'ArrowDown':
        if (!this.open) return
        event.preventDefault()
        this.navigate(this.activeIndex + 1)
        break
      case 'ArrowUp':
        if (!this.open) return
        event.preventDefault()
        this.navigate(this.activeIndex - 1)
        break
      case 'Enter':
        if (!this.open) return
        event.preventDefault() // don't submit the form from the dropdown
        if (this.activeIndex >= 0)
          this.select(this.suggestions[this.activeIndex])
        else this.hide()
        break
      case 'Escape':
        if (!this.open) return
        event.preventDefault()
        event.stopPropagation() // keep an enclosing modal open
        this.hide()
        break
      case 'Tab':
        this.hide()
        break
    }
  }

  navigate(index) {
    const count = this.suggestions.length
    this.activeIndex = ((index % count) + count) % count

    this.listbox.querySelectorAll('[role="option"]').forEach((option, i) => {
      const active = i === this.activeIndex
      option.classList.toggle('combobox__option--navigated', active)
      option.setAttribute('aria-selected', active ? 'true' : 'false')
      if (active) {
        this.line1Target.setAttribute('aria-activedescendant', option.id)
        option.scrollIntoView({ block: 'nearest' })
      }
    })
  }

  clickOption(event) {
    const option = event.target.closest('[role="option"]')
    if (!option) return
    this.select(this.suggestions[Number(option.dataset.index)])
  }

  // --- filling the form ---

  select(suggestion) {
    if (!suggestion) return

    this.fill(this.line1Target, suggestion.line1)
    if (this.hasCityTarget) this.fill(this.cityTarget, suggestion.city)
    if (this.hasPostalCodeTarget)
      this.fill(this.postalCodeTarget, suggestion.postal_code)
    if (this.hasCountryTarget) this.fillCountry(suggestion)
    if (this.hasStateTarget) this.fillState(suggestion)

    this.hide()
  }

  fillState(suggestion) {
    const field = this.stateTarget
    if (field.tagName === 'SELECT') {
      this.fillSelect(field, [suggestion.state_code, suggestion.state_name])
      return
    }

    const coded = CODED_REGION_COUNTRIES.includes(suggestion.country)
    const value = coded
      ? suggestion.state_code || suggestion.state_name
      : suggestion.state_name || suggestion.state_code
    this.fill(field, value)
  }

  fillCountry(suggestion) {
    const field = this.countryTarget
    if (field.tagName === 'SELECT') this.fillSelect(field, [suggestion.country])
    // Text country fields in HCB are fixed ("United States"), so leave them alone
  }

  // Picks the first option whose value or label matches one of `candidates`.
  fillSelect(select, candidates) {
    const wanted = candidates.filter(Boolean).map(c => c.toLowerCase())
    if (wanted.length === 0) return

    const option = Array.from(select.options).find(
      o =>
        wanted.includes(o.value.toLowerCase()) ||
        wanted.includes(o.text.trim().toLowerCase())
    )
    if (option) this.fill(select, option.value)
  }

  fill(field, value) {
    if (field.disabled || value == null || field.value === value) return
    field.value = value
    // Let other controllers (form autosave, herb state, validation) react
    field.dispatchEvent(new Event('input', { bubbles: true }))
    field.dispatchEvent(new Event('change', { bubbles: true }))
  }
}

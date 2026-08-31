import { Controller } from '@hotwired/stimulus'

// Declarative replacement for Alpine's x-show / x-if / x-model / x-bind:required.
//
// The controller element owns the state. Inputs inside it write to a named key
// with `data-conditional-fields-key`; dependents declare when they apply with a
// JSON condition.
//
//   <form data-controller="conditional-fields"
//         data-conditional-fields-state-value='{"type":""}'>
//     <select data-conditional-fields-key="type"
//             data-action="conditional-fields#update">…</select>
//
//     <div data-conditional-fields-when='[{"key":"type","in":["first"]}]'>…</div>
//     <template data-conditional-fields-when='[{"key":"type","in":["vex"]}]'>…</template>
//     <input data-conditional-fields-require='[{"key":"type","present":true}]'>
//   </form>
//
// A condition is a list of clauses, all of which must hold. Supported clauses:
//   {"key":"x","in":[…]}      {"key":"x","notIn":[…]}
//   {"key":"x","present":true} {"key":"x","blank":true}
//   {"key":"x","gt":0}        {"key":"x","gte":0}
//   {"key":"x","lt":0}        {"key":"x","lte":0}
//   {"key":"x","includes":"y"} — x is an array containing the value of key y
//   {"key":"x","match":"re"}   — x matches the regular expression
//
// Besides `-when`, an element may carry `-require`, `-disable` (bind `required`
// / `disabled`), `-clear` (empty the field when the condition stops holding) or
// `-invalid` (+ `-invalid-message`, to block submission while it holds),
// `-class` (+ `-class-name`) or `-text` (+ `-text-on` / `-text-off`).
// `-value="key"` mirrors a state key into a field so it submits with the form.
//   {"any":[clause, …]}       — at least one alternative holds
//
// Expressions are deliberately not supported: evaluating them would mean `eval`,
// which is exactly what dropping Alpine buys us.
export default class extends Controller {
  static values = { state: Object }

  connect() {
    this.inserted = new Map()
    this.cleared = new Map()
    this.fill()
    this.apply()
  }

  // Alpine's `x-model.fill`: seed the state from what the server rendered.
  fill() {
    const seeded = {}
    this.element
      .querySelectorAll('[data-conditional-fields-fill]')
      .forEach(input => {
        const key = input.dataset.conditionalFieldsKey
        if (key) seeded[key] = this.read(input)
      })

    if (Object.keys(seeded).length) {
      this.stateValue = { ...this.stateValue, ...seeded }
    }
  }

  disconnect() {
    this.inserted.forEach(nodes => nodes.forEach(node => node.remove()))
    this.inserted.clear()
  }

  // Mirrors an input's value into the state, then re-applies every dependent.
  update(event) {
    const input = event.currentTarget
    const key = input.dataset.conditionalFieldsKey
    if (key) this.stateValue = { ...this.stateValue, [key]: this.read(input) }

    this.apply()
  }

  // Writes a fixed key/value straight from a click, e.g. a Cancel button that
  // clears the selection.
  assign({ params: { assignKey, assignValue } }) {
    this.stateValue = { ...this.stateValue, [assignKey]: assignValue ?? '' }
    this.apply()
  }

  // Lets a sibling controller write into the state — picking a saved wire
  // recipient, for instance, also sets their country.
  set(event) {
    const { key, value } = event.detail
    this.stateValue = { ...this.stateValue, [key]: value }
    this.apply()
  }

  // `stateValue` is replaced wholesale, so Stimulus calls this on every write.
  stateValueChanged() {
    if (this.inserted) this.apply()
  }

  apply() {
    this.each('[data-conditional-fields-when]', (el, condition) => {
      if (el.tagName === 'TEMPLATE') {
        this.toggleTemplate(el, condition)
      } else {
        el.style.display = this.matches(condition) ? '' : 'none'
      }
    })

    this.each('[data-conditional-fields-require]', (el, condition) => {
      el.required = this.matches(condition)
    })

    this.each('[data-conditional-fields-disable]', (el, condition) => {
      el.disabled = this.matches(condition)
    })

    this.each('[data-conditional-fields-class]', (el, condition) => {
      el.classList.toggle(
        el.dataset.conditionalFieldsClassName,
        this.matches(condition)
      )
    })

    this.each('[data-conditional-fields-text]', (el, condition) => {
      el.textContent = this.matches(condition)
        ? el.dataset.conditionalFieldsTextOn
        : el.dataset.conditionalFieldsTextOff
    })

    // Mirrors a state key into a field, so the choice is submitted with the form.
    this.element
      .querySelectorAll('[data-conditional-fields-value]')
      .forEach(el => {
        if (
          el.closest('[data-controller~="conditional-fields"]') !== this.element
        )
          return

        el.value = this.stateValue[el.dataset.conditionalFieldsValue] ?? ''
      })

    this.each('[data-conditional-fields-invalid]', (el, condition) => {
      el.setCustomValidity(
        this.matches(condition)
          ? el.dataset.conditionalFieldsInvalidMessage
          : ''
      )
    })

    // Emptied as it goes away, not on every pass — a server-rendered value has
    // to survive the first apply.
    this.each('[data-conditional-fields-clear]', (el, condition) => {
      const matched = this.matches(condition)
      if (this.cleared.get(el) === true && !matched) el.value = ''
      this.cleared.set(el, matched)
    })
  }

  // Only elements governed by *this* controller — nested ones own their own.
  each(selector, callback) {
    this.element.querySelectorAll(selector).forEach(el => {
      if (
        el.closest('[data-controller~="conditional-fields"]') !== this.element
      )
        return

      const attribute = selector.slice(1, -1)
      callback(el, JSON.parse(el.getAttribute(attribute)))
    })
  }

  // x-if: the content only exists in the DOM while the condition holds, so
  // `required` fields inside it can't block submission while irrelevant.
  toggleTemplate(template, condition) {
    const shown = this.inserted.has(template)
    const shouldShow = this.matches(condition)
    if (shown === shouldShow) return

    if (shouldShow) {
      const fragment = template.content.cloneNode(true)
      const nodes = Array.from(fragment.children)
      template.after(fragment)
      this.inserted.set(template, nodes)
    } else {
      this.inserted.get(template).forEach(node => node.remove())
      this.inserted.delete(template)
    }
  }

  matches(condition) {
    return (condition || []).every(clause => this.clauseMatches(clause))
  }

  clauseMatches(clause) {
    if (clause.any) return clause.any.some(c => this.clauseMatches(c))

    const value = this.stateValue[clause.key]

    if ('in' in clause && !clause.in.includes(value)) return false
    if ('notIn' in clause && clause.notIn.includes(value)) return false
    if ('present' in clause && this.present(value) !== clause.present)
      return false
    if ('blank' in clause && this.present(value) === clause.blank) return false
    if ('gt' in clause && !(Number(value) > clause.gt)) return false
    if ('gte' in clause && !(Number(value) >= clause.gte)) return false
    if ('lt' in clause && !(Number(value) < clause.lt)) return false
    if ('lte' in clause && !(Number(value) <= clause.lte)) return false
    if ('match' in clause && !new RegExp(clause.match).test(value ?? ''))
      return false
    if ('includes' in clause) {
      if (!Array.isArray(value)) return false
      if (!value.includes(this.stateValue[clause.includes])) return false
    }

    return true
  }

  present(value) {
    return (
      value !== null && value !== undefined && value !== '' && value !== false
    )
  }

  read(input) {
    if (input.type === 'checkbox') return input.checked
    if (input.dataset.conditionalFieldsCast === 'number') {
      return input.value === '' ? null : Number(input.value)
    }
    return input.value
  }
}

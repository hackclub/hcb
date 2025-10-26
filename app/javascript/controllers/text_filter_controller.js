// Adapted from hey.com's `filter_controller`

import { Controller } from '@hotwired/stimulus'

// Connect to an <input type="text"> or <input type="search"> element, making
// sure that its [aria-controls] attribute references an element with
// [role="listbox"], and to declare a [data-filter-attribute-value] attribute to
// instruct the controller on how to filter the descendants of the referenced
// [role="listbox"] element.
//
// <input type="text" aria-controls="listbox_element"
//    data-controller="filter" data-filter-attribute-value="data-name" data-action="input->filter#query">
// <div id="listbox_element" role="listbox">
//   <span role="option" data-name="Alice">Alice</span>
//   <span role="option" data-name="Bob">Bob</span>
//   <span role="option" data-name="Carol">Carol</span>
// </div>
//
export default class extends Controller {
  static classes = ['active', 'empty']
  static values = { attribute: { type: String, default: 'data-name' } }

  query() {
    this.filterOptions()
  }

  selectFirst(e) {
    if (this.isEmpty) return
    const firstOption = [...this.optionElements].filter(visible)[0]

    if (firstOption.tagName == 'BUTTON' || firstOption.tagName == 'A') {
      firstOption.click()
    } else {
      firstOption.querySelector('button', 'a')?.click()
    }

    e.preventDefault()
  }

  // Private

  filterOptions() {
    if (!this.element.isConnected) return
    if (!this.listboxElement) return

    const query = this.comboboxElement.value.trim()

    this.optionElements.forEach(
      applyFilter(query, { matching: this.attributeValue })
    )

    if (this.hasActiveClass)
      this.listboxElement.classList.toggle(this.activeClass, query)
    if (this.hasEmptyClass)
      this.listboxElement.classList.toggle(this.emptyClass, this.isEmpty)
  }

  get comboboxElement() {
    return this.element.querySelector('input[role=combobox]') || this.element
  }

  get listboxElement() {
    const listbox = this.comboboxElement.getAttribute('aria-controls')

    return document.querySelector(listbox)
  }

  get optionElements() {
    return (
      this.listboxElement?.querySelectorAll(`[${this.attributeValue}]`) || []
    )
  }

  get isEmpty() {
    return [...this.optionElements].filter(visible).length == 0
  }
}

function applyFilter(query, { matching }) {
  return target => {
    if (query) {
      const value = target.getAttribute(matching) || ''
      const match = value.toLowerCase().includes(query.toLowerCase())

      target.hidden = !match
    } else {
      target.hidden = false
    }
  }
}

function visible(element) {
  return !element.hidden
}

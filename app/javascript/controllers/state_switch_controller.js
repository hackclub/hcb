import { Controller } from '@hotwired/stimulus'
import { useState } from 'reactionview'

// Shows the parts of a herb view that match a state's value, when which parts
// match comes from data rather than from the template. Wire fields per country
// and Wise fields per currency are lists in the models, so the template can't
// spell out `hidden="<%= selected_country != "CA" %>"` for each of them.
//
//   <div data-controller="state-switch">
//     <fieldset data-state-switch-target="case"
//               data-state-switch-name="selected_country"
//               data-state-switch-when="CA MX">...</fieldset>
//     <fieldset data-state-switch-target="case"
//               data-state-switch-name="account_type"
//               data-state-switch-unless="interac">...</fieldset>
//   </div>
//
// A case is shown when the state's value is one of `when`, or none of
// `unless`. A case that doesn't match is hidden and, if it can be, disabled, so
// its fields are neither submitted nor validated. Render the starting
// `hidden`/`disabled` on the server too, so the page is right before this runs.
export default class extends Controller {
  static targets = ['case']

  connect() {
    useState(this)

    this.listeners = new Map()
    this.caseTargets.forEach(target => this.watch(target))
  }

  disconnect() {
    this.listeners?.forEach(unsubscribe => unsubscribe())
    this.listeners = null
  }

  caseTargetConnected(target) {
    if (this.listeners) this.watch(target)
  }

  watch(target) {
    const name = target.dataset.stateSwitchName

    if (!this.listeners.has(name)) {
      this.listeners.set(
        name,
        this.state.on(name, () => this.refresh(name))
      )
    }

    this.apply(target, this.state.get(name))
  }

  refresh(name) {
    const value = this.state.get(name)

    this.caseTargets
      .filter(target => target.dataset.stateSwitchName === name)
      .forEach(target => this.apply(target, value))
  }

  apply(target, value) {
    const match = this.matches(target, value == null ? '' : String(value))

    target.hidden = !match
    if ('disabled' in target) target.disabled = !match
  }

  matches(target, value) {
    const { stateSwitchWhen: when, stateSwitchUnless: unless } = target.dataset

    if (when !== undefined) return when.split(/\s+/).includes(value)
    if (unless !== undefined) return !unless.split(/\s+/).includes(value)

    return true
  }
}

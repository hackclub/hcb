import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    this.update()
  }

  update() {
    const selected = this.element.querySelector(
      '[name="user[payout_method_type]"]:checked'
    )?.value

    this.element
      .querySelectorAll('[data-payout-method-type]')
      .forEach(section => {
        const active = section.dataset.payoutMethodType === selected

        section.querySelectorAll('input, select, textarea').forEach(input => {
          // Alpine manages `required` itself on these (e.g. Wise fields)
          if (input.hasAttribute('x-bind:required')) {
            if (!active) input.required = false
            return
          }

          if (input.required) input.dataset.payoutRequired = 'true'
          if (input.dataset.payoutRequired) input.required = active
        })
      })
  }
}

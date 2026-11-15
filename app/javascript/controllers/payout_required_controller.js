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

        // Fields that only apply to some countries, currencies or account
        // types sit in disabled fieldsets while they don't apply, which the
        // browser skips when validating, so they're handled like the rest.
        section.querySelectorAll('input, select, textarea').forEach(input => {
          if (input.required) input.dataset.payoutRequired = 'true'
          if (input.dataset.payoutRequired) input.required = active
        })
      })
  }
}

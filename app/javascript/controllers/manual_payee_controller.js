import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'nameInput',
    'emailInput',
    'entityTypeInput',
    'manualOnly',
    'manualField',
    'payeeFormManualField',
    'defaultBanner',
    'manualBanner',
    'enableButton',
    'undoButton',
  ]

  connect() {
    this.renderMode()
  }

  enable() {
    this.manualFieldTarget.value = 'true'
    this.renderMode()
    this.dispatch('changed')
  }

  undo() {
    this.manualFieldTarget.value = 'false'
    this.renderMode()
    this.dispatch('changed')
  }

  get manual() {
    return this.manualFieldTarget.value === 'true'
  }

  continue() {
    if (!this.nameInputTarget.reportValidity()) return
    if (!this.emailInputTarget.reportValidity()) return
    if (this.manual && !this.entityTypeInputTarget.reportValidity()) return

    // Submits to PayeesController, which creates the payee (and, on the manual
    // path, a managed legal entity) then reloads the page with ?payee_id= set.
    document.getElementById('new-payee-form').requestSubmit()
  }

  renderMode() {
    if (this.hasPayeeFormManualFieldTarget) {
      this.payeeFormManualFieldTarget.value = this.manual ? 'true' : 'false'
    }
    this.defaultBannerTarget.hidden = this.manual
    this.manualBannerTarget.hidden = !this.manual
    this.enableButtonTarget.hidden = this.manual
    this.undoButtonTarget.hidden = !this.manual
    this.manualOnlyTargets.forEach(target => {
      target.hidden = !this.manual
    })
  }
}

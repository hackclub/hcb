import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'nameInput',
    'emailInput',
    'entityTypeInput',
    'manualField',
    'payeeNameField',
    'payeeEmailField',
    'payeeEntityTypeField',
    'defaultBanner',
    'manualBanner',
    'enableButton',
    'undoButton',
    'editPanel',
    'summaryPanel',
    'summaryText',
  ]

  enable() {
    this.manualFieldTarget.value = 'true'
    this.sync()

    this.defaultBannerTarget.hidden = true
    this.manualBannerTarget.hidden = false
    this.enableButtonTarget.hidden = true
    this.undoButtonTarget.hidden = false

    this.dispatch('changed')
  }

  undo() {
    this.manualFieldTarget.value = 'false'

    this.defaultBannerTarget.hidden = false
    this.manualBannerTarget.hidden = true
    this.enableButtonTarget.hidden = false
    this.undoButtonTarget.hidden = true

    this.dispatch('changed')
  }

  get manual() {
    return this.manualFieldTarget.value === 'true'
  }

  continue() {
    if (!this.manual) {
      document.getElementById('new-payee-form').requestSubmit()
      return
    }

    if (!this.nameInputTarget.reportValidity()) return
    if (!this.emailInputTarget.reportValidity()) return
    if (!this.entityTypeInputTarget.reportValidity()) return

    this.sync()

    if (this.hasSummaryTextTarget) {
      this.summaryTextTarget.textContent = `${this.nameInputTarget.value} · ${this.emailInputTarget.value}`
    }
    this.editPanelTarget.hidden = true
    if (this.hasSummaryPanelTarget) this.summaryPanelTarget.hidden = false

    document
      .getElementById('payment-details')
      ?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  sync() {
    this.payeeNameFieldTarget.value = this.nameInputTarget.value
    this.payeeEmailFieldTarget.value = this.emailInputTarget.value
    this.payeeEntityTypeFieldTarget.value = this.entityTypeInputTarget.value
  }

  edit() {
    this.editPanelTarget.hidden = false
    if (this.hasSummaryPanelTarget) this.summaryPanelTarget.hidden = true
  }
}

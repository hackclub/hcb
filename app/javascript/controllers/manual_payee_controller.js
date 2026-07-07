import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'nameInput',
    'emailInput',
    'entityTypeInput',
    'manualOnly',
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
    'summaryName',
    'summaryEmail',
    'nextFocus',
  ]

  connect() {
    this.renderMode()
  }

  enable() {
    this.manualFieldTarget.value = 'true'
    this.sync()
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
    if (!this.manual) {
      document.getElementById('new-payee-form').requestSubmit()
      return
    }

    if (!this.nameInputTarget.reportValidity()) return
    if (!this.emailInputTarget.reportValidity()) return
    if (!this.entityTypeInputTarget.reportValidity()) return

    this.sync()
    this.updateSummary()

    this.editPanelTarget.hidden = true
    if (this.hasSummaryPanelTarget) this.summaryPanelTarget.hidden = false

    const paymentDetails = document.getElementById('payment-details')
    if (paymentDetails) {
      const top = paymentDetails.getBoundingClientRect().top + window.scrollY - 100
      window.scrollTo({ top, behavior: 'smooth' })
    }

    this.nextFocusTarget.focus({ preventScroll: true })
  }

  sync() {
    this.payeeNameFieldTarget.value = this.nameInputTarget.value
    this.payeeEmailFieldTarget.value = this.emailInputTarget.value
    this.payeeEntityTypeFieldTarget.value = this.entityTypeInputTarget.value
    this.updateSummary()
  }

  edit() {
    this.editPanelTarget.hidden = false
    if (this.hasSummaryPanelTarget) this.summaryPanelTarget.hidden = true
  }

  renderMode() {
    this.defaultBannerTarget.hidden = this.manual
    this.manualBannerTarget.hidden = !this.manual
    this.enableButtonTarget.hidden = this.manual
    this.undoButtonTarget.hidden = !this.manual
    this.manualOnlyTargets.forEach(target => {
      target.hidden = !this.manual
    })
  }

  updateSummary() {
    this.summaryNameTarget.textContent = this.nameInputTarget.value
    this.summaryEmailTarget.textContent = this.emailInputTarget.value
  }
}

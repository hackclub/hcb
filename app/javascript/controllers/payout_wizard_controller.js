import { Controller } from '@hotwired/stimulus'

// Mirrors transfer_form_controller's "Help me decide" wizard, but instead of
// navigating to a transfer page it selects the matching payout method radio.
export default class extends Controller {
  static targets = [
    // Slides
    'home',
    'wizard',
    'answer',
    // Home slide collapse targets
    'legend',
    'options',
    'help',
    // Wizard slide question targets
    'question',
    'yes',
    'no',
    // Wizard slide answer targets
    'answerText',
    'answerCTA',
    'learnMore',
    'wiseAnswerNote',
  ]

  static questions = [
    {
      id: 1,
      question: 'Does your recipient live within the US?',
      yes: 2,
      no: 3,
    },
    {
      id: 2,
      question: 'Do you have their account & routing number?',
      yes: {
        type: 'ACH transfer',
        link: 'https://help.hcb.hackclub.com/en/articles/15410090-how-do-i-send-an-ach-transfer',
      },
      no: {
        type: 'Mailed check',
        link: 'https://help.hcb.hackclub.com/en/articles/15410094-how-do-i-send-a-check',
      },
    },
    {
      id: 3,
      question: 'Is your transfer amount over $500?',
      yes: {
        type: 'International wire',
        link: 'https://help.hcb.hackclub.com/en/articles/15410092-how-do-i-send-a-wire-transfer',
      },
      no: {
        type: 'Wise transfer',
        link: 'https://help.hcb.hackclub.com/en/articles/15410093-how-do-i-send-a-wise-transfer',
      },
    },
  ]

  static values = {
    collapsible: { type: Boolean, default: true },
  }

  static answerToPayoutMethod = {
    'ACH transfer': 'LegalEntity::PayoutMethod::AchTransfer',
    'Mailed check': 'LegalEntity::PayoutMethod::Check',
    'International wire': 'LegalEntity::PayoutMethod::Wire',
    'Wise transfer': 'LegalEntity::PayoutMethod::WiseTransfer',
  }

  static payoutMethodToSection = {
    'LegalEntity::PayoutMethod::AchTransfer': 'ach_transfer_payout_method_inputs',
    'LegalEntity::PayoutMethod::Check': 'check_payout_method_inputs',
    'LegalEntity::PayoutMethod::Wire': 'wire_payout_method_inputs',
    'LegalEntity::PayoutMethod::WiseTransfer':
      'wise_transfer_payout_method_inputs',
  }

  connect() {
    this.sync()
  }

  // Single source of truth for what's visible. When a method is selected (and the
  // picker is collapsible) we hide the picker list, reveal that method's detail
  // form, and show the back button. Otherwise the picker is shown for choosing.
  sync = () => {
    if (this.collapsibleValue) {
      if (this.checkedRadio()) {
        this.collapseOptions()
        this.syncDetailSections()
      } else {
        this.showOptions()
      }
    } else {
      this.syncDetailSections()
    }
  }

  checkedRadio() {
    return this.optionsTarget.querySelector('input[type="radio"]:checked')
  }

  detailSections() {
    const root = this.element.parentElement || document
    return root.querySelectorAll('[data-behavior$="payout_method_inputs"]')
  }

  // Show only the detail section matching the selected payout method, hiding the
  // rest. Replaces the old jQuery slideUp/slideDown toggles in ui.js.
  syncDetailSections = () => {
    const radio = this.checkedRadio()
    const selected = radio
      ? this.constructor.payoutMethodToSection[radio.value]
      : null

    this.detailSections().forEach(section => {
      const match = section.dataset.behavior === selected
      section.style.display = ''
      section.classList.toggle('hidden', !match)
    })
  }

  hideDetailSections = () => {
    this.detailSections().forEach(section => {
      section.style.display = ''
      section.classList.add('hidden')
    })
  }

  onSelect = () => {
    this.sync()
  }

  // Collapse the picker down to just the selected option, whose checkmark is
  // swapped for a "Change" button via the collapsed modifier (see _forms.scss).
  collapseOptions = () => {
    if (!this.checkedRadio()) return

    this.optionsTarget.classList.add('payout-options--collapsed')
    if (this.hasLegendTarget) this.legendTarget.hidden = true
    this.helpTarget.hidden = true
  }

  // Reveal the full picker again so the user can pick a different method.
  showOptions = () => {
    this.optionsTarget.classList.remove('payout-options--collapsed')
    if (this.hasLegendTarget) this.legendTarget.hidden = false
    this.helpTarget.hidden = false
    this.hideDetailSections()
  }

  showWizard = () => {
    this.homeTarget.hidden = true
    this.answerTarget.hidden = true
    this.wizardTarget.hidden = false
    this.renderQuestion(1)
  }

  hideWizard = () => {
    this.homeTarget.hidden = false
    this.answerTarget.hidden = true
    this.wizardTarget.hidden = true
  }

  reset = () => {
    this.hideWizard()
    this.showWizard()
  }

  renderQuestion = payload => {
    if (typeof payload === 'number') {
      const question = this.constructor.questions.find(q => q.id === payload)
      this.questionTarget.innerHTML = question.question

      this.yesClickHandler = () => this.renderQuestion(question.yes)
      this.noClickHandler = () => this.renderQuestion(question.no)
    } else {
      this.answerTextTarget.innerHTML = payload.type
      this.answerCTATarget.dataset.answer = payload.type
      this.learnMoreTarget.href = payload.link

      this.answerTarget.hidden = false
      this.wizardTarget.hidden = true

      this.wiseAnswerNoteTarget.hidden = payload.type !== 'Wise transfer'
    }
  }

  yesClickHandler = () => {}
  noClickHandler = () => {}

  showAnswer = event => {
    const answer = event.target.dataset.answer
    const payoutMethod = this.constructor.answerToPayoutMethod[answer]

    const radio = this.element.querySelector(
      `input[type="radio"][value="${payoutMethod}"]`
    )

    this.hideWizard()

    if (radio && !radio.disabled) {
      radio.checked = true
      radio.dispatchEvent(new Event('change', { bubbles: true }))
    }
  }
}

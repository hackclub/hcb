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
    'change',
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

  static answerToPayoutMethod = {
    'ACH transfer': 'LegalEntity::PayoutMethod::AchTransfer',
    'Mailed check': 'LegalEntity::PayoutMethod::Check',
    'International wire': 'LegalEntity::PayoutMethod::Wire',
    'Wise transfer': 'LegalEntity::PayoutMethod::WiseTransfer',
  }

  connect() {
    // If a method is already selected on load, start collapsed.
    if (this.checkedRadio()) this.collapseOptions()
  }

  checkedRadio() {
    return this.optionsTarget.querySelector('input[type="radio"]:checked')
  }

  radioLabel(radio) {
    // The visible card is the label bound to this radio.
    return (
      this.optionsTarget.querySelector(`label[for="${radio.id}"]`) ||
      radio.nextElementSibling
    )
  }

  onSelect = () => {
    if (this.checkedRadio()) this.collapseOptions()
  }

  // Hide the unselected cards, leaving just the chosen one plus a "Change" link.
  collapseOptions = () => {
    const checked = this.checkedRadio()
    if (!checked) return

    this.optionsTarget
      .querySelectorAll('input[type="radio"]')
      .forEach(radio => {
        const label = this.radioLabel(radio)
        if (label) label.hidden = radio !== checked
      })

    this.optionsTarget.style.gridTemplateColumns = '1fr'
    this.optionsTarget.style.maxWidth = 'none'
    if (this.hasLegendTarget) this.legendTarget.hidden = true
    this.helpTarget.hidden = true
    this.changeTarget.hidden = false
  }

  // Reveal all cards again so the user can pick a different method.
  showOptions = () => {
    this.optionsTarget
      .querySelectorAll('input[type="radio"]')
      .forEach(radio => {
        const label = this.radioLabel(radio)
        if (label) label.hidden = false
      })

    this.optionsTarget.style.gridTemplateColumns = ''
    if (this.hasLegendTarget) this.legendTarget.hidden = false
    this.helpTarget.hidden = false
    this.changeTarget.hidden = true
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

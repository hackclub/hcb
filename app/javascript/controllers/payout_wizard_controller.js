import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'home',
    'wizard',
    'answer',
    'legend',
    'options',
    'help',
    'question',
    'answerText',
    'answerCTA',
    'learnMore',
    'wiseAnswerNote',
  ]

  static values = {
    collapsible: { type: Boolean, default: true },
  }

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

  static payoutMethods = {
    'ACH transfer': {
      className: 'LegalEntity::PayoutMethod::AchTransfer',
      section: 'ach_transfer_payout_method_inputs',
    },
    'Mailed check': {
      className: 'LegalEntity::PayoutMethod::Check',
      section: 'check_payout_method_inputs',
    },
    'International wire': {
      className: 'LegalEntity::PayoutMethod::Wire',
      section: 'wire_payout_method_inputs',
    },
    'Wise transfer': {
      className: 'LegalEntity::PayoutMethod::WiseTransfer',
      section: 'wise_transfer_payout_method_inputs',
    },
  }

  static WISE_TRANSFER = 'Wise transfer'

  connect() {
    this.sync()
  }


  sync() {
    if (!this.collapsibleValue) {
      this.syncDetailSections()
      return
    }

    if (this.checkedRadio()) {
      this.collapseOptions()
      this.syncDetailSections()
    } else {
      this.showOptions()
    }
  }

  onSelect() {
    this.sync()
  }

  checkedRadio() {
    return this.optionsTarget.querySelector('input[type="radio"]:checked')
  }

  detailSections() {
    const root = this.element.parentElement || document
    return root.querySelectorAll('[data-behavior$="payout_method_inputs"]')
  }

  syncDetailSections() {
    const radio = this.checkedRadio()
    const selectedSection = radio ? this.sectionFor(radio.value) : null

    this.detailSections().forEach(section => {
      section.style.display = ''
      section.classList.toggle(
        'hidden',
        section.dataset.behavior !== selectedSection
      )
    })
  }

  hideDetailSections() {
    this.detailSections().forEach(section => {
      section.style.display = ''
      section.classList.add('hidden')
    })
  }

  collapseOptions() {
    if (!this.checkedRadio()) return

    this.optionsTarget.classList.add('payout-options--collapsed')
    if (this.hasLegendTarget) this.legendTarget.hidden = true
    this.helpTarget.hidden = true
  }

  showOptions() {
    this.optionsTarget.classList.remove('payout-options--collapsed')
    if (this.hasLegendTarget) this.legendTarget.hidden = false
    this.helpTarget.hidden = false
    this.hideDetailSections()
  }

  showWizard() {
    this.homeTarget.hidden = true
    this.answerTarget.hidden = true
    this.wizardTarget.hidden = false
    this.renderStep(1)
  }

  hideWizard() {
    this.homeTarget.hidden = false
    this.answerTarget.hidden = true
    this.wizardTarget.hidden = true
  }

  reset() {
    this.hideWizard()
    this.showWizard()
  }

  yesClickHandler = () => this.advance('yes')
  noClickHandler = () => this.advance('no')

  advance(choice) {
    this.renderStep(this.currentQuestion[choice])
  }

  renderStep(step) {
    if (typeof step === 'number') {
      this.renderQuestion(step)
    } else {
      this.renderRecommendation(step)
    }
  }

  renderQuestion(id) {
    this.currentQuestion = this.constructor.questions.find(q => q.id === id)
    this.questionTarget.innerHTML = this.currentQuestion.question
  }

  renderRecommendation(answer) {
    this.answerTextTarget.innerHTML = answer.type
    this.answerCTATarget.dataset.answer = answer.type
    this.learnMoreTarget.href = answer.link
    this.wiseAnswerNoteTarget.hidden =
      answer.type !== this.constructor.WISE_TRANSFER

    this.wizardTarget.hidden = true
    this.answerTarget.hidden = false
  }

  showAnswer(event) {
    const className = this.classNameFor(event.target.dataset.answer)
    this.hideWizard()

    const radio = this.element.querySelector(
      `input[type="radio"][value="${className}"]`
    )
    if (radio && !radio.disabled) {
      radio.checked = true
      radio.dispatchEvent(new Event('change', { bubbles: true }))
    }
  }

  classNameFor(label) {
    return this.constructor.payoutMethods[label]?.className
  }

  sectionFor(className) {
    const method = Object.values(this.constructor.payoutMethods).find(
      m => m.className === className
    )
    return method?.section
  }
}

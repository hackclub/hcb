import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    // Slides
    'home',
    'wizard',
    'answer',
    // Wizard slide question targets
    'question',
    'yes',
    'no',
    // Wizard slide answer targets
    'answerText',
    'answerCTA',
    'learnMore',
  ]

  static values = {
    ach: String,
    check: String,
    paypal: String,
    wire: String,
    disbursement: String,
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
      yes: [
        'ach',
        'https://help.hcb.hackclub.com/article/59-what-is-an-ach-transfer',
      ],
      no: [
        'check',
        'https://help.hcb.hackclub.com/article/25-what-are-money-transfers',
      ],
    },
    {
      id: 3,
      question: 'Does your recipient have a PayPal account?',
      yes: [
        'paypal',
        'https://help.hcb.hackclub.com/article/25-what-are-money-transfers',
      ],
      no: [
        'wire',
        'https://help.hcb.hackclub.com/article/61-what-are-international-wires',
      ],
    },
  ]

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
      this.answerTextTarget.innerHTML = `${payload[0] === 'ach' ? 'ACH' : payload[0]} transfer`
      this.answerCTATarget.dataset.answer = payload[0]
      this.learnMoreValue = payload[1]

      this.answerTarget.hidden = false
      this.wizardTarget.hidden = true
    }
  }

  showAnswer = event => {
    const answer = event.target.dataset.answer
    window.Turbo.visit(this[`${answer}Value`])
  }
}

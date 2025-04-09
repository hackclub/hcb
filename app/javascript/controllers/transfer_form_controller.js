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
    wire: String,
    disbursement: String,
  }

  static questions = [
    {
      id: 1,
      question: 'Does your recipient live within the US?',
      yes: 2,
      no: {
        type: 'wire',
        link: 'https://help.hcb.hackclub.com/article/61-what-are-international-wires',
      },
    },
    {
      id: 2,
      question: 'Do you have their account & routing number?',
      yes: {
        type: 'ach',
        link: 'https://help.hcb.hackclub.com/article/59-what-is-an-ach-transfer',
      },
      no: {
        type: 'check',
        link: 'https://help.hcb.hackclub.com/article/25-what-are-money-transfers',
      },
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
      this.answerTextTarget.innerHTML = `${payload.type.replace('ach', 'ACH')} transfer`
      this.answerCTATarget.dataset.answer = payload.type
      this.learnMoreTarget.href = payload.link

      this.answerTarget.hidden = false
      this.wizardTarget.hidden = true
    }
  }

  showAnswer = event => {
    const answer = event.target.dataset.answer
    window.Turbo.visit(this[`${answer}Value`])
  }
}

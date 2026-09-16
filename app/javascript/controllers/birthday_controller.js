import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['year', 'month', 'day', 'message']

  connect() {
    this.updateAge()
  }

  updateAge() {
    const year = this.yearTarget.value
    const month = this.monthTarget.value
    const day = this.dayTarget.value

    // If any field is empty, reset UI
    if (!year || !month || !day) {
      this.clearMessage()
      return
    }

    const age = this.calculateAge(year, month, day)

    if (age < 13) {
      this.showMessage(
        'Sorry, you must be at least 13 years old to sign up.',
        true
      )
      this.disableSubmit()
    } else {
      this.clearMessage()
      this.enableSubmit()
    }
  }

  calculateAge(year, month, day) {
    const birthDate = new Date(year, month - 1, day)
    const today = new Date()

    let age = today.getFullYear() - birthDate.getFullYear()
    const monthDiff = today.getMonth() - birthDate.getMonth()

    if (
      monthDiff < 0 ||
      (monthDiff === 0 && today.getDate() < birthDate.getDate())
    ) {
      age--
    }

    return age
  }

  showMessage(text, isWarning = false) {
    this.messageTarget.textContent = text
    this.messageTarget.classList.toggle('warning', isWarning)
  }

  clearMessage() {
    this.messageTarget.textContent = ''
    this.messageTarget.classList.remove('warning')
  }

  disableSubmit() {
    document.getElementById('user_submit')?.setAttribute('disabled', 'disabled')
  }

  enableSubmit() {
    document.getElementById('user_submit')?.removeAttribute('disabled')
  }
}

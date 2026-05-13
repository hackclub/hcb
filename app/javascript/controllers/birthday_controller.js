import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    this.updateAge()
    this.element.classList.add('birthday-inline')
  }

  disconnect() {
    this.element.classList.remove('birthday-inline')
  }

  updateAge() {
    const selects = this.element.querySelectorAll('select[name*="birthday"]')
    let year, month, day

    selects.forEach(select => {
      const name = select.name
      const value = select.value
      if (name.includes('(1i)')) year = value
      if (name.includes('(2i)')) month = value
      if (name.includes('(3i)')) day = value
    })

    const element = document.getElementById('birthday_deterence')
    if (!element) return

    if (!year || !month || !day) {
      element.textContent = ''
      element.classList.remove('warning')
      document.getElementById('user_submit')?.removeAttribute('disabled')
      return
    }

    const birthDate = new Date(
      parseInt(year),
      parseInt(month) - 1,
      parseInt(day)
    )
    const today = new Date()
    let age = today.getFullYear() - birthDate.getFullYear()
    const monthDiff = today.getMonth() - birthDate.getMonth()
    if (
      monthDiff < 0 ||
      (monthDiff === 0 && today.getDate() < birthDate.getDate())
    ) {
      age--
    }

    if (age < 13) {
      element.textContent = `Sorry, you must be at least 13 years old to sign up.`
      element.classList.add('warning')
      document
        .getElementById('user_submit')
        ?.setAttribute('disabled', 'disabled')
    } else if (age >= 13 && age <= 18) {
      element.textContent = `You should join Hack Club`
    } else if (125 > age && age > 100) {
      element.textContent = `Nice to see you found us!`
    } else if (age > 125) {
      element.textContent = `Congrats!`
    } else {
      element.textContent = ''
    }

    if (age >= 13) {
      element.classList.remove('warning')
      document.getElementById('user_submit')?.removeAttribute('disabled')
    }
  }
}

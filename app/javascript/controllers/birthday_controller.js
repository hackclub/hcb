import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    this.updateAge()
    this.element.classList.add('birthday-inline')
    document.getElementById('user_submit')?.removeAttribute('disabled')
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
      element.textContent = `Welcome to the world kiddo!`
      element.classList.add('warning')
      document
        .getElementById('user_submit')
        ?.setAttribute('disabled', 'disabled')
    } else if (age >= 13 && age <= 17) {
      element.textContent = `Join the club!`
    } else if (age >= 18 && age <= 29) {
      element.textContent = `Just left Hack Club?`
    } else if (age >= 30 && age < 50) {
      element.textContent = `That works I guess`
    } else if (age >= 50 && age < 100) {
      element.textContent = `Wow, you are a boomer!`
    } else if (age > 100) {
      element.textContent = `Which era are you from?`
    } else {
      element.textContent = ''
    }

    if (age >= 13) {
      element.classList.remove('warning')
      document.getElementById('user_submit')?.removeAttribute('disabled')
    }
  }
}

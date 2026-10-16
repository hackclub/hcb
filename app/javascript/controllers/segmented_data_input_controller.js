import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['month', 'day', 'year', 'hidden']
  static values = { initial: String, pickerId: String }

  connect() {
    this._onPick = event => {
      if (event.target.dataset.pickerId !== this.pickerIdValue) return
      if (event.detail.start) this.#applyDate(event.detail.start)
    }
    document.addEventListener('daterange:change', this._onPick)

    const match = String(this.initialValue || '').match(/^(\d{2})\/(\d{2})\/(\d{4})$/)
    if (match) {
      const [, month, day, year] = match
      this.monthTarget.value = month
      this.dayTarget.value = day
      this.yearTarget.value = year
    }
    this.#paint()
    this.#syncHidden()
  }

  disconnect() {
    document.removeEventListener('daterange:change', this._onPick)
  }

  onMonthInput(event) {
    event.target.value = event.target.value.replace(/\D/g, '').slice(0, 2)
    this.#paint()
    this.#syncHidden()
    if (event.target.value.length === 2) this.dayTarget.focus()
  }

  onDayInput(event) {
    event.target.value = event.target.value.replace(/\D/g, '').slice(0, 2)
    this.#paint()
    this.#syncHidden()
    if (event.target.value.length === 2) this.yearTarget.focus()
  }

  onYearInput(event) {
    event.target.value = event.target.value.replace(/\D/g, '').slice(0, 4)
    this.#paint()
    this.#syncHidden()
  }

  onKeydown(event) {
    if (event.key !== 'Backspace') return
    if (event.target === this.dayTarget && event.target.value === '') {
      event.preventDefault()
      this.monthTarget.focus()
    } else if (event.target === this.yearTarget && event.target.value === '') {
      event.preventDefault()
      this.dayTarget.focus()
    }
  }

  #applyDate(date) {
    this.monthTarget.value = String(date.getMonth() + 1).padStart(2, '0')
    this.dayTarget.value = String(date.getDate()).padStart(2, '0')
    this.yearTarget.value = String(date.getFullYear())
    this.#paint()
    this.#syncHidden()
  }

  #syncHidden() {
    const month = this.monthTarget.value
    const day = this.dayTarget.value
    const year = this.yearTarget.value
    this.hiddenTarget.value =
      month.length === 2 && day.length === 2 && year.length === 4
        ? `${month}/${day}/${year}`
        : ''
    this.hiddenTarget.dispatchEvent(new Event('change', { bubbles: true }))
  }

  #paint() {
    for (const segment of [this.monthTarget, this.dayTarget, this.yearTarget]) {
      segment.classList.toggle('text-gray-400', segment.value === '')
      segment.classList.toggle('dark:text-gray-600', segment.value === '')
      segment.classList.toggle('text-gray-800', segment.value !== '')
      segment.classList.toggle('dark:text-white', segment.value !== '')
    }
  }
}

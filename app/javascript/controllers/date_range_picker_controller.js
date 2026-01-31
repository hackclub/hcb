import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    initialStart: String,
    initialEnd: String,
    placeholderStart: { type: String, default: 'YYYY-MM-DD' },
    placeholderEnd: { type: String, default: 'YYYY-MM-DD' },
    nameStart: String,
    nameEnd: String,
  }

  connect() {
    this.start = this.#clampDay(this.#parseDate(this.initialStartValue))
    this.end = this.#clampDay(this.#parseDate(this.initialEndValue))
    this.hovered = null
    this.view = this.start || new Date()
    this.typedStart = this.#formatDate(this.start)
    this.typedEnd = this.#formatDate(this.end)
    this.#render()
  }

  setRange({ start, end }) {
    this.start = start ? this.#clampDay(new Date(start)) : null
    this.end = end ? this.#clampDay(new Date(end)) : null
    this.typedStart = this.#formatDate(this.start)
    this.typedEnd = this.#formatDate(this.end)
    this.view = this.start || this.view || new Date()
    this.#render()
    this.#emitChange()
  }

  getRange() {
    return { start: this.start, end: this.end }
  }

  #startOfMonth(date) {
    const result = new Date(date)
    result.setDate(1)
    result.setHours(0, 0, 0, 0)
    return result
  }

  #addMonths(date, monthsToAdd) {
    const result = new Date(date)
    result.setMonth(result.getMonth() + monthsToAdd)
    return result
  }
  #isSameDay(dateA, dateB) {
    return (
      dateA &&
      dateB &&
      dateA.getFullYear() === dateB.getFullYear() &&
      dateA.getMonth() === dateB.getMonth() &&
      dateA.getDate() === dateB.getDate()
    )
  }
  #isBefore(dateA, dateB) {
    return (
      dateA &&
      dateB &&
      new Date(dateA).setHours(0, 0, 0, 0) <
        new Date(dateB).setHours(0, 0, 0, 0)
    )
  }
  #clampDay(date) {
    if (!date) return null
    const result = new Date(date)
    result.setHours(0, 0, 0, 0)
    return result
  }
  #formatDate(date) {
    if (!date) return ''
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }
  #parseDate(dateString) {
    if (!dateString) return null
    const trimmed = String(dateString).trim()

    let match = trimmed.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/)
    if (match) {
      const [, year, monthStr, dayStr] = match
      const month = +monthStr - 1
      const day = +dayStr
      const parsedDate = new Date(+year, month, day)
      return parsedDate.getMonth() === month && parsedDate.getDate() === day
        ? parsedDate
        : null
    }

    match = trimmed.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/)
    if (match) {
      const [, monthStr, dayStr, year] = match
      const month = +monthStr - 1
      const day = +dayStr
      const parsedDate = new Date(+year, month, day)
      return parsedDate.getMonth() === month && parsedDate.getDate() === day
        ? parsedDate
        : null
    }

    return null
  }

  #monthMatrix(viewDate) {
    const monthStart = this.#startOfMonth(viewDate)
    const firstDayOfCalendar = new Date(monthStart)
    const dayOfWeek = firstDayOfCalendar.getDay()
    firstDayOfCalendar.setDate(firstDayOfCalendar.getDate() - dayOfWeek)
    const weeks = []
    let currentDay = new Date(firstDayOfCalendar)
    for (let weekIndex = 0; weekIndex < 6; weekIndex++) {
      const week = []
      for (let dayIndex = 0; dayIndex < 7; dayIndex++) {
        week.push(new Date(currentDay))
        currentDay.setDate(currentDay.getDate() + 1)
      }
      weeks.push(week)
    }
    return { weeks, start: monthStart }
  }

  #formatInputDate(inputValue) {
    let value = inputValue.replace(/\D/g, '')
    if (value.length > 8) value = value.slice(0, 8)

    if (value.length > 6) {
      value = value.replace(/(\d{4})(\d{2})(\d{0,2})/, '$1-$2-$3')
    } else if (value.length > 4) {
      value = value.replace(/(\d{4})(\d{0,2})/, '$1-$2')
    }
    return value
  }

  #render() {
    this.element.innerHTML = this.#template()

    this.$typedStart = this.element.querySelector('[data-role="typed-start"]')
    this.$typedEnd = this.element.querySelector('[data-role="typed-end"]')
    this.$prevBtn = this.element.querySelector('[data-role="prev-month"]')
    this.$nextBtn = this.element.querySelector('[data-role="next-month"]')
    this.$monthTitle = this.element.querySelector('[data-role="month-title"]')
    this.$weeksGrid = this.element.querySelector('[data-role="weeks"]')

    this.$typedStart.addEventListener('input', event => {
      this.typedStart = this.$typedStart.value = this.#formatInputDate(
        event.target.value
      )
    })

    this.$typedEnd.addEventListener('input', event => {
      this.typedEnd = this.$typedEnd.value = this.#formatInputDate(
        event.target.value
      )
    })

    this.$typedStart.addEventListener('blur', () => this.#commitTyped('start'))
    this.$typedEnd.addEventListener('blur', () => this.#commitTyped('end'))

    this.$prevBtn.addEventListener('click', () => {
      this.view = this.#addMonths(this.view, -1)
      this.#renderCalendar()
    })
    this.$nextBtn.addEventListener('click', () => {
      this.view = this.#addMonths(this.view, 1)
      this.#renderCalendar()
    })

    this.#renderCalendar()
  }

  #renderCalendar() {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ]
    this.$monthTitle.textContent = `${monthNames[this.view.getMonth()]} ${this.view.getFullYear()}`

    const { weeks, start: monthStart } = this.#monthMatrix(this.view)
    const allDays = weeks.flat()
    const fragment = document.createDocumentFragment()

    allDays.forEach(day => {
      const isSelectedStart = this.start && this.#isSameDay(day, this.start)
      const isSelectedEnd = this.end && this.#isSameDay(day, this.end)
      const isInRange = this.#inRange(day)
      const isOutsideCurrentMonth = day.getMonth() !== monthStart.getMonth()

      const backgroundClasses = isInRange
        ? 'bg-info text-white'
        : 'bg-transparent'
      const textClasses = isOutsideCurrentMonth
        ? 'text-gray-400 dark:text-gray-600'
        : 'text-gray-800 dark:text-white'

      const button = document.createElement('button')
      button.type = 'button'
      button.setAttribute('aria-label', day.toDateString())
      button.className = `border-0 relative ${backgroundClasses} ${textClasses} h-7 select-none text-sm transition-shadow hover:shadow-sm focus:outline-none focus-visible:ring-2 focus-visible:ring-black`
      button.__day = this.#clampDay(day)

      button.addEventListener('click', event => {
        event.stopPropagation()
        this.#pickDay(button.__day)
      })

      button.addEventListener('mouseenter', () => {
        this.hovered = button.__day
        this.#paintHover()
      })
      button.addEventListener('mouseleave', () => {
        this.hovered = null
        this.#paintHover()
      })

      const span = document.createElement('span')
      span.className = `inline-flex h-full w-full items-center justify-center ${isSelectedStart || isSelectedEnd ? 'font-semibold' : ''}`
      span.textContent = day.getDate()

      button.appendChild(span)
      fragment.appendChild(button)
    })

    this.$weeksGrid.replaceChildren(fragment)
    this.$dayButtons = Array.from(this.$weeksGrid.children)

    this.$typedStart.value = this.#formatDate(this.start)
    this.$typedEnd.value = this.#formatDate(this.end)

    this.#paintHover()
  }

  #shiftDay(date, daysToShift) {
    const result = new Date(date)
    result.setDate(result.getDate() + daysToShift)
    return this.#clampDay(result)
  }

  #paintHover() {
    if (!this.$dayButtons) return

    for (const button of this.$dayButtons) {
      const day = button.__day
      const isStart = this.#isSameDay(day, this.start)
      const isEnd = this.#isSameDay(day, this.end)
      const isHighlighted = this.#inRange(day)

      button.classList.toggle('bg-info', isHighlighted)
      button.classList.toggle('text-white', isHighlighted)
      button.classList.toggle('bg-transparent', !isHighlighted)

      button.style.borderRadius =
        button.style.borderTopLeftRadius =
        button.style.borderTopRightRadius =
        button.style.borderBottomLeftRadius =
        button.style.borderBottomRightRadius =
          ''

      if (isHighlighted) {
        const columnIndex = day.getDay()
        const hasLeftNeighbor =
          columnIndex > 0 && this.#inRange(this.#shiftDay(day, -1))
        const hasRightNeighbor =
          columnIndex < 6 && this.#inRange(this.#shiftDay(day, 1))
        const hasTopNeighbor = this.#inRange(this.#shiftDay(day, -7))
        const hasBottomNeighbor = this.#inRange(this.#shiftDay(day, 7))

        const radius = '10px'
        const roundTopLeft = !hasLeftNeighbor && !hasTopNeighbor
        const roundTopRight = !hasRightNeighbor && !hasTopNeighbor
        const roundBottomLeft = !hasLeftNeighbor && !hasBottomNeighbor
        const roundBottomRight = !hasRightNeighbor && !hasBottomNeighbor

        if (
          roundTopLeft &&
          roundTopRight &&
          roundBottomLeft &&
          roundBottomRight
        ) {
          button.style.borderRadius = radius
        } else {
          button.style.borderTopLeftRadius = roundTopLeft ? radius : '0px'
          button.style.borderTopRightRadius = roundTopRight ? radius : '0px'
          button.style.borderBottomLeftRadius = roundBottomLeft ? radius : '0px'
          button.style.borderBottomRightRadius = roundBottomRight
            ? radius
            : '0px'
        }
      }

      button.firstElementChild?.classList.toggle(
        'font-semibold',
        isStart || isEnd
      )
    }
  }

  #pickDay(day) {
    const previousViewMonth = this.view.getMonth()
    const previousViewYear = this.view.getFullYear()

    if (!this.start || this.end) {
      this.start = day
      this.end = null
      this.view = day
    } else {
      if (this.#isBefore(day, this.start)) {
        this.end = this.start
        this.start = day
      } else {
        this.end = day
      }
    }

    this.typedStart = this.#formatDate(this.start)
    this.typedEnd = this.#formatDate(this.end)

    const hasMonthChanged =
      this.view.getMonth() !== previousViewMonth ||
      this.view.getFullYear() !== previousViewYear

    if (hasMonthChanged) {
      this.#renderCalendar()
    } else {
      this.$typedStart.value = this.#formatDate(this.start)
      this.$typedEnd.value = this.#formatDate(this.end)
      this.#paintHover()
    }

    this.#emitChange()
  }

  #inRange(day) {
    if (this.start && this.end) {
      return !this.#isBefore(day, this.start) && !this.#isBefore(this.end, day)
    }
    if (this.start && this.hovered) {
      const rangeStart = this.#isBefore(this.hovered, this.start)
        ? this.hovered
        : this.start
      const rangeEnd = this.#isBefore(this.hovered, this.start)
        ? this.start
        : this.hovered
      return !this.#isBefore(day, rangeStart) && !this.#isBefore(rangeEnd, day)
    }
    return false
  }

  #commitTyped(whichField) {
    const parsedDate = this.#parseDate(
      whichField === 'start' ? this.typedStart : this.typedEnd
    )
    const inputField =
      whichField === 'start' ? this.$typedStart : this.$typedEnd

    if (!parsedDate) {
      inputField.value = ''
      return
    }

    const day = this.#clampDay(parsedDate)

    if (whichField === 'start') {
      if (this.end && this.#isBefore(this.end, day)) this.end = null
      this.start = day
    } else {
      if (this.start && this.#isBefore(day, this.start)) this.start = day
      this.end = day
    }

    const needsRerender =
      this.view.getMonth() !== day.getMonth() ||
      this.view.getFullYear() !== day.getFullYear()

    this.view = day

    if (needsRerender) {
      this.#renderCalendar()
    } else {
      this.#paintHover()
    }

    this.#emitChange()
  }

  #emitChange() {
    this.element.dispatchEvent(
      new CustomEvent('daterange:change', {
        bubbles: true,
        detail: { start: this.start, end: this.end },
      })
    )
  }

  #template() {
    return `
      <div class="w-full max-w-xl">
        <div class="flex items-center gap-2 mb-3">
          <div class="relative flex-1">
            <input name="${this.nameStartValue}" class="input text-center text-sm" data-role="typed-start" placeholder="${this.placeholderStartValue}" value="${this.typedStart ?? ''}" />
          </div>
          <span class="text-gray-400 select-none">to</span>
          <div class="relative flex-1">
            <input name="${this.nameEndValue}" class="input text-center text-sm" data-role="typed-end" placeholder="${this.placeholderEndValue}" value="${this.typedEnd ?? ''}" />
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between pb-2 px-1">
            <button type="button" data-role="prev-month" class="pop">←</button>
            <div data-role="month-title" class="text-lg font-[700]"></div>
            <button type="button" data-role="next-month" class="pop">→</button>
          </div>

          <div class="grid grid-cols-7 gap-1 text-center text-xs text-gray-500">
            ${['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(dayName => `<div class="py-1">${dayName}</div>`).join('')}
          </div>

          <div data-role="weeks" class="grid grid-cols-7 gap-0 py-2"></div>
          <button type="submit" class="btn w-full">Filter...</button>
        </div>
      </div>
    `
  }
}

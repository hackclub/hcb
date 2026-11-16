import { Controller } from '@hotwired/stimulus'

// Folds a ledger filter form into the ledger's JSON query on submit, so the
// ledger receives one `query` param rather than a param per field.
export default class extends Controller {
  static targets = ['query', 'start', 'end', 'minimum', 'maximum']
  static values = { filters: Object }

  // Whole days: `$gte` the first day, `$lt` the day after the last.
  dates() {
    this.#apply('datetime', {
      $gte: this.startTarget.value || undefined,
      $lt: this.endTarget.value ? nextDay(this.endTarget.value) : undefined,
    })
  }

  amounts() {
    this.#apply('absolute_amount_cents', {
      $gte: cents(this.minimumTarget.value),
      $lte: cents(this.maximumTarget.value),
    })
  }

  merchant({ submitter }) {
    this.#write({ ...this.filtersValue, merchant: submitter.value })
  }

  #apply(field, bounds) {
    const filters = { ...this.filtersValue }
    const range = Object.fromEntries(
      Object.entries(bounds).filter(([, value]) => value !== undefined)
    )

    if (Object.keys(range).length) filters[field] = range
    else delete filters[field]

    this.#write(filters)
  }

  #write(filters) {
    this.queryTarget.value = JSON.stringify(filters)
    this.queryTarget.disabled = !Object.keys(filters).length
  }
}

function nextDay(date) {
  const day = new Date(`${date}T00:00:00Z`)
  day.setUTCDate(day.getUTCDate() + 1)
  return day.toISOString().slice(0, 10)
}

function cents(amount) {
  return amount ? Math.round(parseFloat(amount) * 100) : undefined
}

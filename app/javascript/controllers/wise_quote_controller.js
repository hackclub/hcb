import { Controller } from '@hotwired/stimulus'
import { useState } from 'reactionview'

// Estimates a Wise transfer in USD as its amount and currency are chosen, and
// writes the sentence the form shows to the `usd_estimate` state.
export default class extends Controller {
  static values = { url: String }

  connect() {
    useState(this)
    this.amount = ''
  }

  // The amount's `change`, so it's quoted once the organizer is done typing.
  setAmount({ target }) {
    this.amount = target.value
    this.refresh()
  }

  selected_currencyChanged() {
    this.refresh()
  }

  refresh() {
    const currency = this.state.get('selected_currency')
    const request = (this.request = {})

    if (!this.amount || !currency) {
      this.show('Enter an amount & currency to get an estimate in USD')
      return
    }

    this.show('Loading quote from Wise...')

    const url = new URL(this.urlValue, window.location.origin)
    url.search = new URLSearchParams({ amount: this.amount, currency })

    fetch(url)
      .then(response => response.text())
      .then(quote => {
        if (request === this.request) this.show(`Approximately ${quote} USD`)
      })
  }

  show(text) {
    this.state.set({ usd_estimate: text })
  }
}

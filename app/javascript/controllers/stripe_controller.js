/* global BK */

import { Controller } from '@hotwired/stimulus'
import { loadStripe } from '@stripe/stripe-js'

import themes from '../common/stripeThemes'

export default class extends Controller {
  static targets = ['element', 'errors']
  static values = {
    apiKey: String,
    clientSecret: String,
    returnUrl: String,
    type: { type: String, default: 'payment' }, // "payment" or "setup",
    theme: { type: String, default: 'card' },
  }

  async connect() {
    this.stripe = await loadStripe(this.apiKeyValue)

    this.elements = this.stripe.elements({
      clientSecret: this.clientSecretValue,
      appearance: themes[this.themeValue][BK.isDark() ? 'dark' : 'light'],
    })

    const paymentElement = this.elements.create('payment', {
      business: {
        name: 'HCB',
      },
      terms: { card: 'never' },
    })
    paymentElement.mount(this.elementTarget)
  }

  async submit(e) {
    if (this.hasErrorsTarget) this.errorsTarget.innerHTML = ''

    e.submitter.disabled = true

    const result = await this.confirm()

    e.submitter.disabled = false

    if (result.error) {
      if (result.error.type != 'validation_error') {
        if (this.hasErrorsTarget) {
          const flash = document.createElement('p')
          flash.classList.add('flash', 'error', 'fit', 'mt1', 'mb3')
          if (
            result.error.code == 'payment_intent_authentication_failure' ||
            result.error.code == 'card_declined'
          ) {
            flash.textContent = `Something went wrong: your bank declined this transaction. Please contact them to approve it.`
          } else {
            flash.textContent = `Something went wrong: ${result.error.message}`
          }
          this.errorsTarget.appendChild(flash)
        } else {
          alert(`Something went wrong: ${result.error.message}`)
        }
      }
    }
  }

  themeToggle({ detail: dark }) {
    this.elements.update({
      appearance: themes[this.themeValue][dark ? 'dark' : 'light'],
    })
  }

  async confirm() {
    if (this.typeValue == 'payment') {
      return await this.stripe.confirmPayment({
        elements: this.elements,
        confirmParams: {
          return_url: this.returnUrlValue,
        },
      })
    } else {
      return await this.stripe.confirmSetup({
        elements: this.elements,
        confirmParams: {
          return_url: this.returnUrlValue,
        },
      })
    }
  }
}

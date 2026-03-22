import { Controller } from '@hotwired/stimulus'
import { get } from '@github/webauthn-json'
import { appsignal } from '../appsignal'

class UserVisibleError extends Error {}

export default class extends Controller {
  static targets = ['responseInput', 'continueButton', 'errorCard']

  static values = {
    optionsUrl: String,
  }

  async connect() {
    this.continueButtonTarget.disabled = true

    try {
      const options = await this.fetchOptions()
      const credential = await this.retrieveCredential(options)

      this.responseInputTarget.value = JSON.stringify(credential)
      this.continueButtonTarget.disabled = false
      this.continueButtonTarget.form.requestSubmit(this.continueButtonTarget)
    } catch (error) {
      let message = 'Unexpected error'

      if (error instanceof UserVisibleError) {
        message = error.message
      } else {
        appsignal.sendError(error)
      }

      this.errorCardTarget.innerText = message
      this.errorCardTarget.classList.remove('hidden')
    }
  }

  async fetchOptions() {
    const optionsResponse = await fetch(this.optionsUrlValue)

    if (optionsResponse.status == 404) {
      throw new UserVisibleError(
        'No security keys found. Please use a different method.'
      )
    } else if (!optionsResponse.ok) {
      throw new UserVisibleError('Unexpected server error')
    }

    return optionsResponse.json()
  }

  async retrieveCredential(options) {
    try {
      return await get({ publicKey: options })
    } catch {
      throw new UserVisibleError(
        'Failed to verify security key. Please use a different method.'
      )
    }
  }
}

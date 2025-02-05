import { Controller } from '@hotwired/stimulus'
import { get } from '@github/webauthn-json'
import UAParser from 'ua-parser-js'
import FingerprintJS from '@fingerprintjs/fingerprintjs'
import submitForm from '../common/submitForm'
import airbrake from '../airbrake'

export default class extends Controller {
  static targets = [
    'authForm',
    'loginEmailInput',
    'error',
    'loginCode',
    'continueButton',
    'loginPreferenceWebauthnInput',
    'rememberInput',
  ]

  static values = {
    returnTo: String,
    requireWebauthnPreference: Boolean,
    loginId: String,
  }

  initialize() {
    this.submitting = false
  }

  loginEmailInputTargetConnected() {
    this.loginEmailInputTarget.value ||= localStorage.getItem('login_email')
  }

  async submit(event) {
    if (this.submitting) return

    if (
      this.hasLoginPreferenceWebauthnInputTarget &&
      !this.loginPreferenceWebauthnInputTarget.checked
    ) {
      return
    }

    event.preventDefault()
    event.stopImmediatePropagation()

    this.disableForm()

    const loginEmail = event.target.email.value

    try {
      const options = await this.fetchWebAuthnOptions(loginEmail)

      if (this.hasLoginCodeTarget) {
        this.loginCodeTarget.classList.remove('display-none')
      }
      this.continueButtonTarget.value = 'Waiting for security key...'

      const credential = await get({
        publicKey: options,
      })

      this.storeLoginEmail(loginEmail)

      submitForm(
        this.loginIdValue
          ? `/logins/${this.loginIdValue}/complete`
          : `/logins/complete`,
        {
          credential: JSON.stringify(credential),
          return_to: this.returnToValue,
          method: 'webauthn',
          remember:
            this.hasRememberInputTarget && this.rememberInputTarget.checked,
          ...(await this.fingerprint()),
        }
      )
    } catch (e) {
      if (e.message == "User doesn't have WebAuthn enabled") {
        // Submit the form normally
        this.storeLoginEmail(loginEmail)

        this.submitting = true
        event.target.requestSubmit()
      } else {
        // Show an error
        this.enableForm()
        this.continueButtonTarget.value = 'Continue'

        this.errorTarget.classList.remove('display-none')

        console.error(e)
        airbrake?.notify(e)
      }
    }
  }

  disableForm() {
    this.authFormTarget
      .querySelectorAll('input[type=submit], button')
      .forEach(x => (x.disabled = true))
  }

  enableForm() {
    this.authFormTarget
      .querySelectorAll('input[type=submit], button')
      .forEach(x => (x.disabled = false))
  }

  storeLoginEmail(email) {
    localStorage.setItem('login_email', email)
  }

  async fetchWebAuthnOptions(email) {
    const searchParams = new URLSearchParams()
    searchParams.set('email', email)
    if (this.requireWebauthnPreferenceValue) {
      searchParams.set('require_webauthn_preference', true) // Only continue if the user prefers WebAuthn for this session
    }

    const options = await fetch(
      `/users/webauthn/auth_options?${searchParams}`
    ).then(r => {
      if (!r.ok) throw new Error("User doesn't have WebAuthn enabled")

      return r.json()
    })

    return options
  }

  async fingerprint() {
    const result = new UAParser().getResult()
    const fingerprint = await FingerprintJS.load().then(fp => fp.get())

    return {
      fingerprint: fingerprint.visitorId,
      device_info: result.browser.name + ' ' + result.browser.version,
      os_info: result.os.name + ' ' + result.os.version,
      timezone: fingerprint.components.timezone.value,
    }
  }
}

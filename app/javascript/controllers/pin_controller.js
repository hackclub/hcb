import { Controller } from '@hotwired/stimulus'
import { loadStripe } from '@stripe/stripe-js'

export default class extends Controller {
  static values = {
    stripeId: String,
    cardId: String,
    stripeApiKey: String,
  }

  async view() {
    const stripe = await loadStripe(this.stripeApiKeyValue)

    const nonceResult = await stripe.createEphemeralKeyNonce({
      issuingCard: this.stripeIdValue,
    })

    const nonce = nonceResult.nonce

    const ephemeralKeyResult = await fetch(
      `/stripe_cards/${this.cardIdValue}/ephemeral_keys?nonce=${nonce}`
    )

    const ephemeralKeyResponse = await ephemeralKeyResult.json()

    const ephemeralKeySecret = ephemeralKeyResponse.ephemeralKeySecret

    const pinElement = stripe.elements().create('issuingCardPinDisplay', {
      issuingCard: this.stripeIdValue,
      nonce: nonce,
      ephemeralKeySecret: ephemeralKeySecret,
    })

    pinElement.mount('#card-pin')
  }
}

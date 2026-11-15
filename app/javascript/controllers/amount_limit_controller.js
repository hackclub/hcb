import { Controller } from '@hotwired/stimulus'
import { useState } from 'reactionview'

// Compares a dollar amount field with a limit in cents and writes the answer to
// a herb state. A herb view can only compare a state with a literal or another
// state, and these limits come from the server (`Invoice::MAX_CARD_AMOUNT`, an
// organization's balance), so the arithmetic happens here.
//
//   <div data-controller="amount-limit"
//        data-amount-limit-max-value="<%= most_allowed_cents %>"
//        data-amount-limit-state-value="card_limit">
//     <%= form.number_field :amount, data: { amount_limit_target: "input", action: "amount-limit#update" } %>
//   </div>
//
//   <p hidden="<%= card_limit != "over" %>">That's more than a card can pay.</p>
//
// The state is "" while the field holds no amount, "within" for an amount up to
// and including `max`, and "over" for anything more.
export default class extends Controller {
  static targets = ['input']
  static values = { max: Number, state: String }

  connect() {
    useState(this)
  }

  update() {
    const cents = Math.round(parseFloat(this.inputTarget.value) * 100)

    let answer = ''
    if (cents) answer = cents > this.maxValue ? 'over' : 'within'

    this.state.set({ [this.stateValue]: answer })
  }
}

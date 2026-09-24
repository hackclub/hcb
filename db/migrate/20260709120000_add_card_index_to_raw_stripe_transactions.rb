# frozen_string_literal: true

class AddCardIndexToRawStripeTransactions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # `stripe_transaction->>'card'` is the Stripe card id. The pre-existing index is
  # on `(stripe_transaction -> 'card') ->> 'id'`, a different expression, so joins
  # against the card id could not use it.
  def change
    add_index :raw_stripe_transactions,
              "(stripe_transaction ->> 'card')",
              name: "index_raw_stripe_transactions_on_card",
              algorithm: :concurrently
  end

end

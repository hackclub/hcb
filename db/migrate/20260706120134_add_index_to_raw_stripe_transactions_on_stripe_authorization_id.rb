# frozen_string_literal: true

class AddIndexToRawStripeTransactionsOnStripeAuthorizationId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :raw_stripe_transactions, :stripe_authorization_id, algorithm: :concurrently
  end

end

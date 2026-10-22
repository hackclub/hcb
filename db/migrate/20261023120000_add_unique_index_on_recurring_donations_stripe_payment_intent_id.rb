# frozen_string_literal: true

class AddUniqueIndexOnRecurringDonationsStripePaymentIntentId < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :donations, :stripe_payment_intent_id,
              unique: true,
              where: "recurring_donation_id IS NOT NULL AND stripe_payment_intent_id IS NOT NULL",
              name: "index_donations_on_recurring_stripe_payment_intent_id",
              algorithm: :concurrently
  end

end

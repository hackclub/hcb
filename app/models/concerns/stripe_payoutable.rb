# frozen_string_literal: true

# Shared concern for models that represent a Stripe payout (e.g. InvoicePayout,
# DonationPayout). Extracts the identical field-mapping and payout-creation
# logic so each model only needs to implement #stripe_payout_params and
# #default_values.
module StripePayoutable
  extend ActiveSupport::Concern

  included do
    # Stripe provides a field called type, which is reserved in rails for STI.
    # This removes the Rails reservation on 'type' for this class.
    self.inheritance_column = nil

    # `paid` payouts can still transition to `failed`
    scope :should_sync, -> { where(status: ["pending", "in_transit"]).or(where(status: "paid", stripe_created_at: 3.days.ago..)) }

    before_create :create_stripe_payout
  end

  def set_fields_from_stripe_payout(payout)
    self.amount = payout.amount
    self.arrival_date = Util.unixtime(payout.arrival_date)
    self.automatic = payout.automatic
    self.stripe_balance_transaction_id = payout.balance_transaction
    self.stripe_created_at = Util.unixtime(payout.created)
    self.currency = payout.currency
    self.description = payout.description
    self.stripe_destination_id = payout.destination
    self.failure_stripe_balance_transaction_id = payout.failure_balance_transaction
    self.failure_code = payout.failure_code
    self.failure_message = payout.failure_message
    self.method = payout.method
    self.source_type = payout.source_type
    self.statement_descriptor = payout.statement_descriptor
    self.status = payout.status
    self.type = payout.type
  end

  private

  def create_stripe_payout
    payout = StripeService::Payout.create(stripe_payout_params)
    self.stripe_payout_id = payout.id

    set_fields_from_stripe_payout(payout)
  end
end

# frozen_string_literal: true

module StripePayoutable
  extend ActiveSupport::Concern

  included do
    # Stripe provides a field called type, which is reserved in Rails for STI.
    # This removes the Rails reservation on 'type' for this class.
    self.inheritance_column = nil

    scope :should_sync, lambda {
      where(status: %w[pending in_transit]).or(where(status: "paid", stripe_created_at: 3.days.ago..))
    } # `paid` payouts can still transition to `failed`

    after_initialize :default_values
    before_create :create_stripe_payout
  end

  class_methods do
    attr_reader :stripe_payout_subject_name

    def stripe_payoutable(subject_name)
      @stripe_payout_subject_name = subject_name.to_sym
    end
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

  def default_values
    return unless payout_subject

    self.statement_descriptor ||= "HCB-#{local_hcb_code.short_code}"
  end

  def create_stripe_payout
    payout = StripeService::Payout.create(stripe_payout_params)
    self.stripe_payout_id = payout.id

    set_fields_from_stripe_payout(payout)
  end

  def payout_subject
    public_send(self.class.stripe_payout_subject_name)
  end
end

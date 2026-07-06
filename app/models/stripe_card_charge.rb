# frozen_string_literal: true

# == Schema Information
#
# Table name: stripe_card_charges
#
#  id                                :bigint           not null, primary key
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  raw_pending_stripe_transaction_id :bigint
#
# Indexes
#
#  index_stripe_card_charges_on_raw_pending_stripe_transaction_id  (raw_pending_stripe_transaction_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (raw_pending_stripe_transaction_id => raw_pending_stripe_transactions.id) ON DELETE => nullify
#
# Raw objects are matched to their charge purely by Stripe IDs: a
# RawPendingStripeTransaction's `stripe_transaction_id` and a
# RawStripeTransaction's `stripe_authorization_id` both hold the Stripe
# authorization ID (iauth_...).
class StripeCardCharge < ApplicationRecord
  belongs_to :raw_pending_stripe_transaction, optional: true
  has_and_belongs_to_many :raw_stripe_transactions

  has_one :ledger_item, class_name: "Ledger::Item", as: :linked_object

  def stripe_card
    (raw_stripe_transactions.last || raw_pending_stripe_transaction)&.stripe_card
  end

  def stripe_cardholder
    stripe_card&.stripe_cardholder
  end

  def merchant_data
    (raw_stripe_transactions.last || raw_pending_stripe_transaction)&.stripe_transaction&.dig("merchant_data")
  end

  def merchant_currency
    (raw_stripe_transactions.last || raw_pending_stripe_transaction)&.stripe_transaction&.dig("merchant_currency")
  end

  # Finds the charge for a Stripe authorization ID (iauth_...), whether it was
  # first seen as an authorization or as a settled transaction.
  def self.matching_stripe_authorization_id(stripe_authorization_id)
    return nil if stripe_authorization_id.blank?

    joins(:raw_pending_stripe_transaction)
      .find_by(raw_pending_stripe_transactions: { stripe_transaction_id: stripe_authorization_id }) ||
      joins(:raw_stripe_transactions)
        .find_by(raw_stripe_transactions: { stripe_authorization_id: })
  end

  def self.link_raw_pending_stripe_transaction!(raw_pending_stripe_transaction)
    existing = raw_pending_stripe_transaction.stripe_card_charge ||
               matching_stripe_authorization_id(raw_pending_stripe_transaction.stripe_transaction_id)

    if existing
      # A settled transaction can arrive before its authorization (e.g. during
      # backfills); the authorization claims the charge it left behind.
      existing.update!(raw_pending_stripe_transaction:) if existing.raw_pending_stripe_transaction_id.nil?
      existing
    else
      create!(raw_pending_stripe_transaction:)
    end
  end

  def self.link_raw_stripe_transaction!(raw_stripe_transaction)
    existing = raw_stripe_transaction.stripe_card_charge
    return existing if existing

    # Force captures have no authorization, so they get a charge of their own.
    charge = matching_stripe_authorization_id(raw_stripe_transaction.stripe_authorization_id)
    if charge
      charge.raw_stripe_transactions << raw_stripe_transaction
      charge
    else
      create!(raw_stripe_transactions: [raw_stripe_transaction])
    end
  end

end

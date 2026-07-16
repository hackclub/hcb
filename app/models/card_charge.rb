# frozen_string_literal: true

# == Schema Information
#
# Table name: card_charges
#
#  id                                :bigint           not null, primary key
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  raw_pending_stripe_transaction_id :bigint
#
# Indexes
#
#  index_card_charges_on_raw_pending_stripe_transaction_id  (raw_pending_stripe_transaction_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (raw_pending_stripe_transaction_id => raw_pending_stripe_transactions.id) ON DELETE => nullify
#
# Raw objects are matched to their charge purely by Stripe IDs: a
# RawPendingStripeTransaction's `stripe_transaction_id` and a
# RawStripeTransaction's `stripe_authorization_id` both hold the Stripe
# authorization ID (iauth_...).
class CardCharge < ApplicationRecord
  belongs_to :raw_pending_stripe_transaction, optional: true
  has_many :card_charge_raw_stripe_transactions, dependent: :destroy
  has_many :raw_stripe_transactions, through: :card_charge_raw_stripe_transactions

  has_one :ledger_item, class_name: "Ledger::Item", as: :linked_object

  scope :on_card, ->(stripe_card) {
    left_joins(:raw_pending_stripe_transaction, :raw_stripe_transactions)
      .where(
        "raw_pending_stripe_transactions.stripe_transaction->'card'->>'id' = :stripe_id OR raw_stripe_transactions.stripe_transaction->>'card' = :stripe_id",
        stripe_id: stripe_card.stripe_id
      )
  }

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

  def icon
    merchant = YellowPages::Merchant.lookup(network_id: merchant_data["network_id"])
    category = merchant_data["category"]
    categorised_category = BreakdownEngine::Categorizer.new(category).run

    if merchant.icon.present?
      merchant
    elsif %w[passenger_railways railroads commuter_transport_and_ferries].include?(category)
      "train"
    elsif categorised_category == "Food"
      "food"
    elsif categorised_category == "Apparel"
      "shirt"
    else
      "card"
    end
  end

  # Finds the charge for a Stripe authorization ID (iauth_...), whether it was
  # first seen as an authorization or as a settled transaction.
  def self.find_by_stripe_authorization_id(stripe_authorization_id)
    return nil if stripe_authorization_id.blank?

    joins(:raw_pending_stripe_transaction).find_by(raw_pending_stripe_transactions: { stripe_transaction_id: stripe_authorization_id }) ||
      joins(:raw_stripe_transactions).find_by(raw_stripe_transactions: { stripe_authorization_id: })
  end

  def self.link_raw_pending_stripe_transaction!(raw_pending_stripe_transaction)
    if existing = raw_pending_stripe_transaction.card_charge || find_by_stripe_authorization_id(raw_pending_stripe_transaction.stripe_transaction_id)
      existing.update!(raw_pending_stripe_transaction:) if existing.raw_pending_stripe_transaction_id.nil?

      existing
    else
      create!(raw_pending_stripe_transaction:)
    end
  end

  def self.link_raw_stripe_transaction!(raw_stripe_transaction)
    existing = raw_stripe_transaction.card_charge
    return existing if existing.present?

    charge = if charge = find_by_stripe_authorization_id(raw_stripe_transaction.stripe_authorization_id)
               charge.raw_stripe_transactions << raw_stripe_transaction unless charge.raw_stripe_transactions.include?(raw_stripe_transaction)

               charge
             else
               create!(raw_stripe_transactions: [raw_stripe_transaction])
             end

    # Reading card_charge above caches nil on the has_one :through, and
    # creating the join record from the charge's side doesn't write it back.
    raw_stripe_transaction.association(:card_charge_raw_stripe_transaction).reset
    raw_stripe_transaction.association(:card_charge).reset

    charge
  end

end

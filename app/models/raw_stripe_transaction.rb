# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_stripe_transactions
#
#  id                      :bigint           not null, primary key
#  amount_cents            :integer
#  date_posted             :date
#  stripe_transaction      :jsonb
#  unique_bank_identifier  :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  stripe_authorization_id :text
#  stripe_transaction_id   :text
#
# Indexes
#
#  index_raw_stripe_transactions_on_card                     (((stripe_transaction ->> 'card'::text)))
#  index_raw_stripe_transactions_on_card_id_text             ((((stripe_transaction -> 'card'::text) ->> 'id'::text))) USING hash
#  index_raw_stripe_transactions_on_stripe_authorization_id  (stripe_authorization_id)
#
class RawStripeTransaction < ApplicationRecord
  has_many :hashed_transactions
  has_one :canonical_transaction, as: :transaction_source
  has_one :card_charge_raw_stripe_transaction
  has_one :card_charge, through: :card_charge_raw_stripe_transaction

  after_create :link_card_charge!

  def memo
    @memo ||= stripe_transaction.dig("merchant_data", "name")
  end

  def merchant_category
    stripe_transaction&.dig("merchant_data", "category")
  end

  def likely_event
    Event.find(likely_event_id) if likely_event_id
  end

  def likely_card_grant
    ::StripeCard.find_by(stripe_id: stripe_card_id)&.card_grant
  end

  def likely_event_id
    @likely_event_id ||= ::StripeCard.find_by!(stripe_id: stripe_card_id).event_id
  end

  def refund?
    stripe_transaction["type"] == "refund"
  end

  def link_card_charge!
    CardCharge.link_raw_stripe_transaction!(self)
  end

  def stripe_card
    ::StripeCard.find_by!(stripe_id: stripe_card_id)
  end

  private

  def stripe_card_id
    stripe_transaction["card"]
  end

end

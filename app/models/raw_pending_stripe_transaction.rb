# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_pending_stripe_transactions
#
#  id                    :bigint           not null, primary key
#  amount_cents          :integer
#  date_posted           :date
#  stripe_transaction    :jsonb
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  stripe_transaction_id :text
#
# Indexes
#
#  index_raw_pending_stripe_transactions_on_card_id_text           ((((stripe_transaction -> 'card'::text) ->> 'id'::text))) USING hash
#  index_raw_pending_stripe_transactions_on_cardholder_id          (((((stripe_transaction -> 'card'::text) -> 'cardholder'::text) ->> 'id'::text)))
#  index_raw_pending_stripe_transactions_on_status_text            (((stripe_transaction ->> 'status'::text))) USING hash
#  index_raw_pending_stripe_transactions_on_stripe_transaction_id  (stripe_transaction_id) UNIQUE
#
class RawPendingStripeTransaction < ApplicationRecord
  monetize :amount_cents

  has_one :canonical_pending_transaction

  scope :reversed, -> { where("stripe_transaction->>'status' = 'reversed'") }
  scope :pending, -> { where("stripe_transaction->>'status' = 'pending'") }

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| record.stripe_card&.user || User.find_by(email: "bank@hackclub.com") }, event_id: proc { |controller, record| record.stripe_card&.event&.id }, recipient: proc { |controller, record| record.stripe_card&.user }, only: [:create]

  def date
    date_posted
  end

  def memo
    stripe_transaction.dig("merchant_data", "name")
  end

  def likely_event_id
    @likely_event_id ||= ::StripeCard.find_by(stripe_id: stripe_card_id)&.event_id
  end

  def stripe_card
    @stripe_card ||= StripeCard.find_by(stripe_id: stripe_card_id)
  end

  def authorization_method
    stripe_transaction["authorization_method"].humanize.downcase
  end

  private

  def stripe_card_id
    stripe_transaction.dig("card", "id")
  end

end
